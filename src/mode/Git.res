let getLastRev = () =>
  switch Env.get("CI_COMMIT_BEFORE_SHA") {
  | Some("0000000000000000000000000000000000000000") =>
    switch Env.get("CI_DEFAULT_BRANCH") {
    | Some(def_branch) =>
      Proc.run(["git", "merge-base", "HEAD", `origin/${def_branch}`])->TaskResult.map(String.trim)
    | None => Error("CI_COMMIT_REF_NAME or CI_DEFAULT_BRANCH not set")->Task.resolve
    }
  | Some(val) => Ok(val)->Task.resolve
  | None => Ok("HEAD^")->Task.resolve
  }

let cmpInts = (intsNew: array<Instance.t>, intsOld: array<Instance.t>) => {
  let hashsOld = intsOld->Array.map(Hash.hash)
  intsNew->Array.filter(intNew => !(hashsOld->Array.includes(intNew->Hash.hash)))
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
    Ok(filesOld->String.includes(confPath) ? intsNew->cmpInts(intsOld) : [])->Task.resolve
  })
}

let handleFileChange = (confPath, filePath) => {
  confPath
  ->Config.loadFile
  ->Result.map(ints =>
    ints->Array.filter(({folder}) => folder->String.endsWith(filePath->Path.dirname))
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
  Console.log("Git Mode: Create instances from changed files in git")
  let lastRev = getLastRev()
  lastRev
  ->TaskResult.flatMap(lastRev => {
    Console.log(`Last revision: ${lastRev}`)
    Proc.run(["git", "diff", "--name-only", lastRev, "HEAD"])
  })
  ->TaskResult.flatMap(output => {
    output
    ->String.trim
    ->String.split("\n")
    ->Array.filter(File.exists)
    ->Array.reduce((a, file) => {
      a->Array.concat(file->handleChange)
    }, [])
    ->Task.seq
    ->Task.map(tasks =>
      tasks
      ->Result.seq
      ->Result.map(confs => {
        let ints = confs->Array.flatten
        let (_, ints) = ints->Array.reduce(((intsHash, ints), int) => {
          let newHash = int->Hash.hash
          intsHash->Array.some(oldHash => oldHash == newHash)
            ? (intsHash, ints)
            : (intsHash->Array.concat([newHash]), ints->Array.concat([int]))
        }, ([], []))
        ints
      })
    )
  })
}
