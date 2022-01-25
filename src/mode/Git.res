let getLastRev = () =>
  switch Env.get("CI_COMMIT_BEFORE_SHA") {
  | Some("0000000000000000000000000000000000000000") =>
    switch Env.get("CI_DEFAULT_BRANCH") {
    | Some(def_branch) =>
      Proc.run(["git", "merge-base", "HEAD", `origin/${def_branch}`])->TaskResult.map(
        Js.String2.trim,
      )
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
    Proc.run(["git", "show", `HEAD:${confPath}`])->TaskResult.map(Config.load(_, confPath))
  let lastRev = getLastRev()
  let intsOld =
    lastRev->TaskResult.flatMap(lastRev =>
      Proc.run(["git", "show", `${lastRev}:${confPath}`])->TaskResult.map(conf =>
        conf->Config.load(confPath)
      )
    )

  let lastRev = getLastRev()
  let filesOld = lastRev->TaskResult.flatMap(lastRev => Proc.run(["git", "ls-tree", "-r", lastRev]))

  (intsNew, intsOld, filesOld)
  ->TaskResult.seq3
  ->TaskResult.flatMap(((intsNew, intsOld, filesOld)) => {
    Ok(filesOld->Js.String2.includes(confPath) ? intsNew->cmpInts(intsOld) : [])->Task.resolve
  })
}

let handleFileChange = (confPath, filePath) => {
  confPath
  ->Config.loadFile
  ->Result.map(ints =>
    ints->Js.Array2.filter(({folder}) => folder->Js.String2.endsWith(filePath->Path.dirname))
  )
  ->Task.resolve
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
  ->TaskResult.flatMap(lastRev => {
    Js.Console.log(`Last revision: ${lastRev}`)
    Proc.run(["git", "diff", "--name-only", lastRev, "HEAD"])
  })
  ->TaskResult.flatMap(output => {
    output
    ->Js.String2.trim
    ->Js.String2.split("\n")
    ->Js.Array2.filter(File.exists)
    ->Js.Array2.reduce((a, file) => {
      a->Array.concat(file->handleChange)
    }, [])
    ->Task.seq
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
}
