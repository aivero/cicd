let getCurBranch = () => {
  Env.get("CI_COMMIT_REF_NAME")->Option.toResult("CI_COMMIT_REF_NAME not defined!")
}

let getMergeBase = (curBranch, branch) => {
  Proc.run(["git", "merge-base", curBranch, branch])
  ->TaskResult.map(String.trim)
  ->TaskResult.flatMap(mergeBase =>
    Proc.run(["git", "rev-list", "--count", `${curBranch}...${mergeBase}`])
    ->TaskResult.flatMap(output =>
      output->String.trim->Int.fromString->Option.toResult("Couldn't convert to int")->Task.resolve
    )
    ->TaskResult.map(countMergeBase => (countMergeBase, branch, mergeBase))
  )
}

let getParentBranch = () => {
  let curBranch = getCurBranch()->Task.resolve
  (curBranch, Proc.run(["git", "branch", "-a"]))
  ->TaskResult.seq2
  ->TaskResult.flatMap(((curBranch, output)) => {
    let branches =
      output
      ->String.trim
      ->String.split("\n")
      ->Array.map(String.trim)
      ->Array.filter(branch =>
        !(branch->String.startsWith("*") || branch->String.endsWith(`/${curBranch}`))
      )
    branches
    ->Array.map(getMergeBase(curBranch))
    ->TaskResult.seq
    ->TaskResult.flatMap(mergeBases =>
      Array.sort(mergeBases, ((a, _, _), (b, _, _)) => a - b)[0]
      ->Option.toResult("No merge bases")
      ->Task.resolve
    )
  })
  ->TaskResult.map(((_, branch, commit)) => (branch, commit))
}

let getLastRev = () =>
  switch Env.get("CI_COMMIT_BEFORE_SHA") {
  | Some("0000000000000000000000000000000000000000") =>
    getParentBranch()->TaskResult.map(((_, commit)) => commit)
  | Some(val) => val->TaskResult.resolve
  | None => "HEAD^"->TaskResult.resolve
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
    (filesOld->String.includes(confPath) ? intsNew->cmpInts(intsOld) : [])->TaskResult.resolve
  })
}

let handleFileChange = (confPath, filePath) => {
  confPath
  ->Config.loadFile
  ->Result.map(Array.filter(_, ({folder}) => folder->String.endsWith(filePath->Path.dirname)))
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
    ->Array.flatMap(handleChange)
    ->TaskResult.seq
    ->TaskResult.map(confs => {
      let ints = confs->Array.flatten
      let (_, ints) = ints->Array.reduce(((intsHash, ints), int) => {
        let newHash = int->Hash.hash
        intsHash->Array.some(oldHash => oldHash == newHash)
          ? (intsHash, ints)
          : (intsHash->Array.concat([newHash]), ints->Array.concat([int]))
      }, ([], []))
      ints
    })
  })
}
