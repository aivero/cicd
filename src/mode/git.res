let lastRev = switch Env.get("CI_COMMIT_BEFORE_SHA") {
| Some(val) => val
| None => "HEAD^"
}

let cmpInts = (intsNew: array<Instance.t>, intsOld: array<Instance.t>) => {
  let hashsOld = intsOld->Array.map(Hash.hash)
  intsNew->Js.Array2.filter(intNew => !(hashsOld->Js.Array2.includes(intNew->Hash.hash)))
}

let handleConfigChange = confPath => {
  // New config.yml
  let intsNew =
    Proc.run(["git", "show", `HEAD:${confPath}`])->Task.thenResolve(conf =>
      switch (conf) {
      | Ok(conf) => conf->Config.load(confPath)->Flat.array
      | Error(conf) => Error(conf)
      }
    )
  let intsOld =
    Proc.run(["git", "show", `${lastRev}:${confPath}`])->Task.thenResolve(conf =>
      switch (conf) {
      | Ok(conf) => conf->Config.load(confPath)->Flat.array
      | Error(conf) => Error(conf)
      }
    )
  let filesOld = Proc.run(["git", "ls-tree", "-r", lastRev])

  (intsNew, intsOld, filesOld)
  ->Task.all3
  ->Task.flatMap(((intsNew, intsOld, filesOld)) => {
    switch (intsNew, intsOld, filesOld) {
    | (Ok(intsNew), Ok(intsOld), Ok(filesOld)) if filesOld->Js.String.includes(confPath) =>
      intsNew->cmpInts(intsOld)->Array.map(Job.load)->Task.all->Task.map((a) => a->Array.concatMany->Flat.array)
    | (Error(err), _, _) => Error(err)->Task.resolve
    | _ => Ok([])->Task.resolve
    }
  })
}

let handleFileChange = (confPath, filePath) => {
  switch confPath->Config.loadFile {
  | Ok(ints) =>
    ints
    ->Js.Array2.filter(({folder}) => {
      switch folder {
      | Some(folder) => folder
      | None => ""
      }->Js.String.endsWith(filePath->Path.dirname)
    })
    ->Array.map(Job.load)
    ->Task.all->Task.map((a) => a->Array.concatMany->Flat.array)
  | Error(err) => Error(err)->Task.resolve
  }
}

let handleChange = file => {
  let conf = file->Path.dirname->Config.find
  switch conf {
  | Some(conf) if conf->Path.basename == Config.name => [conf->handleConfigChange]
  | Some(conf) => [conf->handleFileChange(file)]
  | None => []
  }
}

let findJobs = () => {
  Js.Console.log("Git Mode: Create instances from changed files in git")
  Proc.run(["git", "diff", "--name-only", lastRev, "HEAD"])->Task.then(output =>
    output
    ->Result.getExn
    ->Js.String.trim
    ->Js.String2.split("\n")
    ->Js.Array2.filter(File.exists)
    ->Js.Array.reduce((a, file) => {
      a->Array.concat(file->handleChange)
    }, [], _)
    ->Task.all->Task.then((tasks) => tasks->Flat.array->Result.map(Array.concatMany)->Task.resolve)
  )
}