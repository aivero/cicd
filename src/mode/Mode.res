open Instance

let findAllInts = recursive => {
  let cmd =
    ["git", "ls-files", "**devops.yml"]->Array.concat(recursive ? ["--recurse-submodules"] : [])
  Proc.run(cmd)->TaskResult.flatMap(e =>
    e
    ->String.trim
    ->String.split("\n")
    ->Array.map(Config.loadFile)
    ->Result.seq
    ->Result.map(Array.flatten)
    ->Task.resolve
  )
}

let findReqs = (ints, allInts) => {
  TaskResult.seq2((ints, allInts))->TaskResult.flatMap(((ints, allInts)) => {
    let reqs = ints->Array.flatMap(int => int.reqs)
    let reqs =
      allInts->Array.filter(int =>
        reqs->Array.includes(int.name) && !(ints->Array.some(int => reqs->Array.includes(int.name)))
      )
    Ok(ints->Array.concat(reqs))->Task.resolve
  })
}

let load = () => {
  let kind = Env.get("mode")
  let recursive = Env.get("recursive")
  let source = Env.get("CI_PIPELINE_SOURCE")

  let recursive = switch recursive {
  | Some("true") | Some("1") => true
  | Some("false") | Some("0") => false
  | _ => true
  }

  let allInts = recursive->findAllInts

  let ints = switch (kind, source) {
  | (Some("manual"), _) => allInts->Manual.findInts
  | (Some("git"), _) => Git.findInts()
  | (Some(mode), _) => Error(`Mode not supported: ${mode}`)->Task.resolve
  | (None, Some("web")) => allInts->Manual.findInts
  | (None, _) => Git.findInts()
  }

  let ints = ints->findReqs(allInts)

  ints->TaskResult.flatMap(Job.load)
}
