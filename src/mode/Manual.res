let filter = (ints: array<Instance.t>, comps) => {
  ints->Js.Array2.filter(({name, version}) => {
    comps->Js.Array2.some(comp =>
      switch (comp[0], comp[1]) {
      | (Some("*"), Some("*")) => true
      | (Some("*"), Some(cversion)) => cversion == version
      | (Some(cname), Some("*")) => cname == name
      | (Some(cname), None) => cname == name
      | _ => false
      }
    ) &&
      !(
        comps->Js.Array2.some(comp =>
          switch comp[0] {
          | Some(cname) if cname->Js.String2.startsWith("-") =>
            cname->Js.String2.sliceToEnd(~from=1) == name
          | _ => false
          }
        )
      )
  })
}

let findInts = allInts => {
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
