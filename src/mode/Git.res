let getLastRev = () =>
  switch Env.get("CI_COMMIT_BEFORE_SHA") {
  | Some("0000000000000000000000000000000000000000") =>
    switch Env.get("CI_DEFAULT_BRANCH") {
    | Some(def_branch) =>
      Proc.run(["git", "merge-base", "HEAD", def_branch])
    | None => Error("CI_COMMIT_REF_NAME or CI_DEFAULT_BRANCH not set")->Task.resolve
    }
  | Some(val) => Ok(val)->Task.resolve
  | None => Ok("HEAD^")->Task.resolve
  }

let cmpInts = (intsNew: array<Instance.t>, intsOld: array<Instance.t>) => {
  let hashsOld = intsOld->Array.map(Hash.hash)
  intsNew->Js.Array2.filter(intNew => !(hashsOld->Js.Array2.includes(intNew->Hash.hash)))
}

let handleConfigChange = confPath => {
  let intsNew =
    Proc.run(["git", "show", `HEAD:${confPath}`])->TaskResult.flatMap(conf =>
      conf->Config.load(confPath)->Seq.result
    )
  let lastRev = getLastRev()
  let intsOld =
    lastRev->TaskResult.map(lastRev =>
      Proc.run(["git", "show", `${lastRev}:${confPath}`])->TaskResult.flatMap(conf =>
        conf->Config.load(confPath)->Seq.result
      )
    )->TaskResult.flatten
  let lastRev = getLastRev()
  let filesOld = lastRev->TaskResult.map(lastRev => Proc.run(["git", "ls-tree", "-r", lastRev]))->TaskResult.flatten

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
  let lastRev = getLastRev()
  lastRev
  ->TaskResult.map(lastRev => Proc.run(["git", "diff", "--name-only", lastRev, "HEAD"]))
  ->TaskResult.flatten
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
      ->Seq.result
      ->Result.map(confs => {
        let ints = confs->Flat.array
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
  ->TaskResult.flatten
}
