open Instance

let findAllInts = recursive => {
  let cmd =
    ["git", "ls-files", "**devops.yml"]->Array.concat(recursive ? ["--recurse-submodules"] : [])
  Proc.run(cmd)->Task.flatMap(e =>
    e
    ->String.trim
    ->String.split("\n")
    ->Array.map(Config.loadFile)
    ->Result.seq
    ->Result.map(Array.flatten)
    ->Task.fromResult
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
  Task.seq2((ints, allInts))->Task.flatMap(((ints, allInts)) => {
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
    ->Task.to
  })
}

let load = () => {
  let kind = Env.get("mode")
  let component = Env.get("component")
  let recursive = Env.get("recursive")
  let source = Env.get("CI_PIPELINE_SOURCE")

  let recursive = switch recursive {
  | Some("true") | Some("1") => true
  | Some("false") | Some("0") => false
  | _ => true
  }

  let allInts = recursive->findAllInts

  let ints = switch (kind, source, component) {
  | (Some("manual"), _, _) => allInts->Manual.findInts
  | (Some("git"), _, _) => Git.findInts()
  | (Some(mode), _, _) => `Mode not supported: ${mode}`->Task.toError
  | (None, Some("web"), Some(_)) => allInts->Manual.findInts
  | (None, _, _) => Git.findInts()
  }

  let ints = ints->addReqs(allInts)

  ints->Task.flatMap(Job.load)
}
