let lastRev = switch Env.get("CI_COMMIT_BEFORE_SHA") {
| Some(val) => val
| None => "HEAD^"
}

let cmpInts = (intsNew: array<Instance.t>, intsOld: array<Instance.t>) => {
  let hashsOld = intsOld->Array.map(Hash.hash)
  intsNew->Js.Array2.filter(intNew => !(hashsOld->Js.Array2.includes(intNew->Hash.hash)))
}

let handleConfigChange = confPath => {
  let intsNew =
    Proc.run(["git", "show", `HEAD:${confPath}`])->TaskResult.flatMap(conf =>
      conf->Config.load(confPath)->Flat.array
    )
  let intsOld =
    Proc.run(["git", "show", `${lastRev}:${confPath}`])->TaskResult.flatMap(conf =>
      conf->Config.load(confPath)->Flat.array
    )
  let filesOld = Proc.run(["git", "ls-tree", "-r", lastRev])

  (intsNew, intsOld, filesOld)
  ->Task.all3
  ->Task.map(((intsNew, intsOld, filesOld)) => {
    switch (intsNew, intsOld, filesOld) {
    | (Ok(intsNew), Ok(intsOld), Ok(filesOld)) if filesOld->Js.String2.includes(confPath) =>
      Ok(intsNew->cmpInts(intsOld))
    | (Error(err), _, _) => Error(err)
    | _ => Ok([])
    }
  })
}

let handleFileChange = (confPath, filePath) => {
  switch confPath->Config.loadFile {
  | Ok(ints) =>
    Ok(
      ints->Js.Array2.filter(({folder}) => {
        switch folder {
        | Some(folder) => folder
        | None => ""
        }->Js.String2.endsWith(filePath->Path.dirname)
      }),
    )
  | Error(err) => Error(err)
  }->Task.resolve
}

let handleChange = file => {
  let conf = file->Path.dirname->Config.find
  switch conf {
  | Some(conf) if file->Path.basename == Config.name => [conf->handleConfigChange]
  | Some(conf) => [conf->handleFileChange(file)]
  | None => []
  }
}

let findInts = () => {
  Js.Console.log("Git Mode: Create instances from changed files in git")
  Proc.run(["git", "diff", "--name-only", lastRev, "HEAD"])
  ->TaskResult.map(output => {
    output
    ->Js.String2.trim
    ->Js.String2.split("\n")
    ->Js.Array2.filter(File.exists)
    ->Js.Array2.reduce((a, file) => {
      a->Array.concat(file->handleChange)
    }, [])
    ->Task.all
    ->Task.map(tasks =>
      tasks
      ->Flat.array
      ->Result.map(confs => {
        let ints = confs->Array.concatMany
        let (_, ints) = ints->Js.Array2.reduce(((intsHash, ints), int) => {
          let newHash = int->Hash.hash
          intsHash->Js.Array2.some(oldHash => oldHash == newHash)
            ? (intsHash, ints)
            : (intsHash->Js.Array2.concat([newHash]), ints->Js.Array2.concat([int]))
        }, ([], []))
        ints
      })
    )
  })
  ->Flat.task
}
