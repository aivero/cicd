open Instance

let findReqs = ints => {
  let allInts =
    Proc.run(["git", "ls-files", "**devops.yml", "--recurse-submodules"])->Task.map(e =>
      e
      ->Result.getExn
      ->Js.String2.trim
      ->Js.String2.split("\n")
      ->Array.map(Config.loadFile)
      ->Flat.array
      ->Result.map(Array.concatMany)
    )

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

  let ints = switch kind {
  | Some("manual") => Manual.findInts()
  | _ => Git.findInts()
  }

  let ints = ints->findReqs

  ints
  ->TaskResult.flatMap(ints => {
    let zips = ints->Instance.zip
    zips->Job.load
  })
  ->Flat.task
}
