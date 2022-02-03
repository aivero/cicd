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
  ->Task.fold(output => {
    Console.log(`Branch "${branch}" failed with output: \n${output}`)
    (99999, "00000000000", branch)
  })
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
  switch (getCurBranch(), Env.getError("CI_COMMIT_BEFORE_SHA")) {
  | (Ok("master"), Ok(commit)) => ("master", commit)->Task.to
  | (Ok(_), _) => getParentBranch()->Task.map(((ref, commit)) => (ref, commit))
  | _ => "Couldn't find last rev"->Task.toError
  }

let cmpInts = (intsNew: array<Instance.t>, intsOld: array<Instance.t>) => {
  let hashsOld = intsOld->Array.map(Hash.hash)
  intsNew->Array.filter(intNew => !(hashsOld->Array.includes(intNew->Hash.hash)))
}

let handleConfigChange = confPath => {
  `Config changed: ${confPath}`->Console.log
  let intsNew = Proc.run(["git", "show", `HEAD:${confPath}`])->Task.map(Config.load(_, confPath))
  let lastRev = getLastRev()

  let intsOld =
    lastRev
    ->Task.flatMap(((_, lastRev)) =>
      (Proc.run(["git", "ls-tree", "-r", lastRev]), lastRev->Task.to)->Task.seq2
    )
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
  `File changed: ${filePath}`->Console.log
  confPath
  ->Config.loadFile
  ->Result.map(
    Array.filter(_, ({folder}) => {
      let match = filePath->Path.dirname->String.startsWith(folder)
      `${folder}: ${match->Bool.toString}`->Console.log
      match
    }),
  )
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
  ("CI_COMMIT_REF_NAME", "CI_COMMIT_SHA")
  ->Tuple.map2(Env.getError)
  ->Result.seq2
  ->Task.fromResult
  ->Task.flatMap(((branch, commit)) => Proc.run(["git", "checkout", "-B", branch, commit]))
  ->Task.flatMap(_ => getLastRev())
  ->Task.flatMap(((branch, commit)) => {
    Console.log(`Last branch: ${branch}`)
    Console.log(`Last commit: ${commit}`)
    Proc.run(["git", "diff", "--name-only", commit, "HEAD"])
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
