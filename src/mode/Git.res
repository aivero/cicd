let getCurBranch = () => {
  Env.getError("CI_COMMIT_REF_NAME")
}

let getDefaultBranch = () => {
  Env.getError("CI_DEFAULT_BRANCH")
}

let getMergeBase = (curBranch, branch) => {
  Proc.run(["git", "merge-base", curBranch, branch])
  ->Task.map(String.trim)
}

let getParentBranch = () =>
  switch (Env.getError("CI_TARGET_BRANCH_NAME"), getDefaultBranch()) {
  | (Ok(""), Ok(branch)) => branch
  | (Ok(branch), _) => branch
  | (_, Ok("")) => "master"
  | (_, Ok(branch)) => branch
  | _ => "master"
  }

let getLastRev = () =>
  switch (getCurBranch(), Env.getError("CI_COMMIT_BEFORE_SHA")) {
  | (Ok("master"), Ok("0000000000000000000000000000000000000000")) => ("master", "HEAD^")->Task.to
  | (Ok("master"), Ok(commit)) => ("master", commit)->Task.to
  | (Ok(curBranch), _) => {
    let parentBranch = getParentBranch()
    getMergeBase(curBranch, parentBranch)->Task.map((ref) => (parentBranch, ref))
  }
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
      filesOld->String.includes(`\t${confPath}`)
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
      let ints = confs->Array.flat
      let (_, ints) = ints->Array.reduce(((intsHash, ints), int) => {
        let newHash = int->Hash.hash
        intsHash->Array.some(oldHash => oldHash == newHash)
          ? (intsHash, ints)
          : {
              `Found instance: ${int.name}/${int.version} (mode: ${int.mode->Instance.modeToString}) (${newHash})`->Console.log
              (intsHash->Array.concat([newHash]), ints->Array.concat([int]))
            }
      }, ([], []))
      ints
    })
  })
}
