open Instance

let findAllInts = recursive => {
  let cmd =
    ["git", "ls-files", "**devops.yml"]->Js.Array2.concat(recursive ? ["--recurse-submodules"] : [])
  Proc.run(cmd)->TaskResult.flatMap(e =>
    e
    ->Js.String2.trim
    ->Js.String2.split("\n")
    ->Array.map(Config.loadFile)
    ->Seq.result
    ->Result.map(Flat.array)
    ->Task.resolve
  )
}

let findReqs = (ints, allInts) => {
  TaskResult.seq2((ints, allInts))->TaskResult.flatMap(((ints, allInts)) => {
    let reqs = ints->Array.map(int => int.reqs)->Flat.array
    let reqs =
      allInts->Js.Array2.filter(int =>
        reqs->Js.Array2.includes(int.name) &&
          !(ints->Array.some(int => reqs->Js.Array2.includes(int.name)))
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
