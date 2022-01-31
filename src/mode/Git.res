let getCurBranch = () => {
  Env.getError("CI_COMMIT_REF_NAME")
}

let getMergeBase = (curBranch, branch) => {
  Proc.run(["git", "merge-base", curBranch, branch])
  ->Task.map(String.trim)
  ->Task.flatMap(mergeBase =>
    Proc.run(["git", "rev-list", "--count", `${curBranch}...${mergeBase}`])
    ->Task.flatMap(output =>
      output
      ->String.trim
      ->Int.fromString
      ->Option.toResult("Couldn't convert to int")
      ->Task.fromResult
    )
    ->Task.map(countMergeBase => (countMergeBase, branch, mergeBase))
  )
}

let getParentBranch = () => {
  let curBranch = getCurBranch()->Task.fromResult
  (curBranch, Proc.run(["git", "branch", "-a"]))
  ->Task.seq2
  ->Task.flatMap(((curBranch, output)) => {
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
    ->Task.seq
    ->Task.flatMap(mergeBases =>
      Array.sort(mergeBases, ((a, _, _), (b, _, _)) => a - b)[0]
      ->Option.toResult("No merge bases")
      ->Task.fromResult
    )
  })
  ->Task.map(((_, branch, commit)) => (branch, commit))
}

let getLastRev = () =>
  switch Env.get("CI_COMMIT_BEFORE_SHA") {
  | Some("0000000000000000000000000000000000000000") =>
    getParentBranch()->Task.map(((_, commit)) => commit)
  | Some(val) => val->Task.to
  | None => "HEAD^"->Task.to
  }

let cmpInts = (intsNew: array<Instance.t>, intsOld: array<Instance.t>) => {
  let hashsOld = intsOld->Array.map(Hash.hash)
  intsNew->Array.filter(intNew => !(hashsOld->Array.includes(intNew->Hash.hash)))
}

let handleConfigChange = confPath => {
  let intsNew = Proc.run(["git", "show", `HEAD:${confPath}`])->Task.map(Config.load(_, confPath))
  let lastRev = getLastRev()

  let filesOld = lastRev->Task.flatMap(lastRev => Proc.run(["git", "ls-tree", "-r", lastRev]))
  let intsOld =
    (filesOld, lastRev)
    ->Task.seq2
    ->Task.flatMap(((filesOld, lastRev)) =>
      filesOld->String.includes(confPath)
        ? Proc.run(["git", "show", `${lastRev}:${confPath}`])->Task.map(Config.load(_, confPath))
        : []->Task.to
    )

  (intsNew, intsOld)
  ->Task.seq2
  ->Task.flatMap(((intsNew, intsOld)) => {
    intsNew->cmpInts(intsOld)->Task.to
  })
}

let handleFileChange = (confPath, filePath) => {
  confPath
  ->Config.loadFile
  ->Result.map(Array.filter(_, ({folder}) => folder->String.endsWith(filePath->Path.dirname)))
  ->Task.fromResult
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
  Proc.run(["git", "checkout", "-B", "$CI_COMMIT_REF_NAME", "$CI_COMMIT_SHA"])
  ->Task.flatMap(_ => getLastRev())
  ->Task.flatMap(lastRev => {
    Console.log(`Last revision: ${lastRev}`)
    Proc.run(["git", "diff", "--name-only", lastRev, "HEAD"])
  })
  ->Task.flatMap(output => {
    output
    ->String.trim
    ->String.split("\n")
    ->Array.filter(File.exists)
    ->Array.flatMap(handleChange)
    ->Task.seq
    ->Task.map(confs => {
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
