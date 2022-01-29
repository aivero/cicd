let filter = (ints: array<Instance.t>, comps) => {
  ints->Array.filter(({name, version}) => {
    comps->Array.some(comp =>
      switch (comp[0], comp[1]) {
      | (Some("*"), Some("*")) => true
      | (Some("*"), Some(cversion)) => cversion == version
      | (Some(cname), Some("*")) => cname == name
      | (Some(cname), None) => cname == name
      | _ => false
      }
    ) &&
      !(
        comps->Array.some(comp =>
          switch comp[0] {
          | Some(cname) if cname->String.startsWith("-") =>
            cname->String.sliceToEnd(~from=1) == name
          | _ => false
          }
        )
      )
  })
}

let findInts = allInts => {
  Console.log("Manual Mode: Create instances from manual args")
  let comps = switch Env.get("component") {
  | Some(comps) => {
      `Building components: ${comps}`->Console.log
      comps->String.split(",")->Array.map(comp => comp->String.split("/"))
    }
  | None => []
  }

  allInts->Task.map(ints => ints->filter(comps))
}
