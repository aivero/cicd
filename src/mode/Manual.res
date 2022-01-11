let filter = (ints: array<Instance.t>, comps) => {
  ints->Js.Array2.filter(int => {
    switch (int.name, int.version) {
    | (Some(cname), Some(cversion)) =>
      comps->Js.Array2.some(comp =>
        switch (comp[0], comp[1]) {
        | (Some(name), Some(version)) if name == "*" && version == "*" => true
        | (Some(name), Some(version)) if name == "*" => cversion == version
        | (Some(name), Some(version)) if version == "*" => cname == name
        | (Some(name), None) => cname == name
        | _ => false
        }
      ) &&
        !(
          comps->Js.Array2.some(comp =>
            switch comp[0] {
            | Some(name) if name->Js.String2.startsWith("-") => name->Js.String2.sliceToEnd(~from=1) == cname
            | _ => false
            }
          )
        )
    | _ => false
    }
  })
}

let findInts = () => {
  Js.Console.log("Manual Mode: Create instances from manual args")
  let comps = switch Env.get("component") {
  | Some(comps) => comps->Js.String.split(",")->Array.map(comp => comp->Js.String.split("/"))
  | None => []
  }

  Proc.run(["git", "ls-files", "**devops.yml", "--recurse-submodules"])->TaskResult.flatMap(e =>
    e
    ->Js.String2.trim
    ->Js.String2.split("\n")
    ->Array.map(Config.loadFile)
    ->Flat.array
    ->Result.map(conf => conf->Array.concatMany->filter(comps))
  )
}
