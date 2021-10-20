let filterConfig = (ints: array<Instance.t>, name, version) =>
  ints->Js.Array2.filter(int => {
    switch (int.name, int.version) {
    | (Some(cname), Some(cversion)) =>
      switch (name, version) {
      | ("*", "*") => true
      | (_, "*") => cname == name
      | ("*", _) => cversion == version
      | (_, _) => cname == name && cversion == version
      }
    | _ => false
    }
  })

let findInts = () => {
  Js.Console.log("Manual Mode: Create instances from manual args")
  let [name, version] = switch Env.get("component")->Option.map(Js.String.split("/")) {
  | Some([name, version]) => [name, version]
  | _ => ["", ""]
  }

  Proc.run(["git", "ls-files", "**devops.yml", "--recurse-submodules"])->Task.map(e =>
    e
    ->Result.getExn
    ->Js.String2.trim
    ->Js.String2.split("\n")
    ->Array.map(Config.loadFile)
    ->Flat.array
    ->Result.map(conf =>
      conf
      ->Array.concatMany
      ->filterConfig(name, version)
    )
  )
}
