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

let rec findReqs = (int, allInts) => {
  allInts->Array.flatMap(aint =>
    if int.needs->Array.includes(aint.name) || int.trigger->Array.includes(aint.name) {
      let reqs = aint->findReqs(allInts)
      reqs->Array.some(req =>
        req.needs->Array.includes(aint.name) || req.trigger->Array.includes(aint.name)
      )
        ? reqs
        : [aint]->Array.concat(reqs)
    } else {
      []
    }
  )
}

let addReqs = (ints, allInts) => {
  TaskResult.seq2((ints, allInts))->TaskResult.flatMap(((ints, allInts)) => {
    let reqs = ints->Array.flatMap(findReqs(_, allInts))
    let ints =
      reqs
      ->Array.filter(req => !(ints->Array.some(int => int.name == req.name)))
      ->Array.concat(ints)
    ints
    ->Array.map(triggered => {
      let triggers =
        ints
        ->Array.filter(int => int.trigger->Array.includes(triggered.name))
        ->Array.map(trigger => `${trigger.name}/${trigger.version}`)
      {
        ...triggered,
        needs: triggered.needs->Array.concat(triggers),
      }
    })
    ->TaskResult.resolve
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

  let ints = ints->addReqs(allInts)

  ints->TaskResult.flatMap(Job.load)
}
