let findNeeds = ints => {
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
    allInts->Result.flatMap(allInts => {
      ints->Result.map(ints => {
        let needs = allInts->Js.Array2.filter((int: Instance.t) =>
          switch int.name {
          | Some(name) => ints->Array.some((int: Instance.t) =>
              switch int.needs {
              | Some(needs) => needs->Js.Array2.includes(name)
              | _ => false
              }
            )
          | _ => false
          }
        )
        ints->Array.concat(needs)
      })
    })
  })
}

let load = () => {
  let kind = Env.get("mode")

  let ints = switch kind {
  | Some("manual") => Manual.findInts()
  | _ => Git.findInts()
  }

  let ints = ints->findNeeds

  ints
  ->Task.map(res => {
    res->Result.flatMap(ints => {
      let zips = ints->Instance.zip
      zips->Job.load
    })
  })
  ->Flat.task
}
