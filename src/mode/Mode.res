open Instance

let findAllInts = recursive => {
  let cmd = ["git", "ls-files", "**devops.yml", "--recurse-submodules"]->Js.Array2.concat(recursive ? ["--recurse-submodules"] : [])
  Proc.run(cmd)->TaskResult.flatMap(e =>
    e
    ->Js.String2.trim
    ->Js.String2.split("\n")
    ->Array.map(Config.loadFile)
    ->Flat.array
    ->Result.map(Array.concatMany)
  )
}

let findReqs = (ints, allInts) => {
  Task.all2((ints, allInts))->Task.map(((ints, allInts)) => {
    switch (ints, allInts) {
    | (Ok(ints), Ok(allInts)) => {
        let reqs =
          ints
          ->Array.map(int =>
            switch int.req {
            | Some(req) => req
            | None => []
            }
          )
          ->Array.concatMany
        let reqs = allInts->Js.Array2.filter(int => {
          switch int.name {
          | Some(name) => reqs->Js.Array2.includes(name)
          | None => false
          } &&
          !(
            ints->Array.some(int =>
              switch int.name {
              | Some(name) => reqs->Js.Array2.includes(name)
              | None => false
              }
            )
          )
        })
        Ok(ints->Array.concat(reqs))
      }
    | (Error(error), _) => Error(error)
    | (_, Error(error)) => Error(error)
    }
  })
}

let load = () => {
  let kind = Env.get("mode")
  let recursive = Env.get("recursive")
  let source = Env.get("CI_PIPELINE_SOURCE")

  let recursive = switch recursive {
  | Some(_) => true
  | _ => false
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

  ints
  ->TaskResult.flatMap(ints => {
    let zips = ints->Instance.zip
    zips->Job.load
  })
  ->Flat.task
}
