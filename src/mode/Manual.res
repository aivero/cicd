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
            | Some(name) if name->Js.String2.startsWith("-") =>
              name->Js.String2.sliceToEnd(~from=1) == cname
            | _ => false
            }
          )
        )

    | _ => false
    }
  })
}

let findInts = (allInts) => {
  Js.Console.log("Manual Mode: Create instances from manual args")
  let comps = switch Env.get("component") {
  | Some(comps) => {
      `Building components: ${comps}`->Js.Console.log
      comps->Js.String2.split(",")->Array.map(comp => comp->Js.String2.split("/"))
    }
  | None => []
  }

  allInts->TaskResult.map(ints => ints->filter(comps))
}
