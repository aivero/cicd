@send external toString: 'a => string = "toString"

let main = () => {
  let _ = Mode.load()->Task.map(res =>
    switch res {
    | Ok(val) => {
        val->Gitlab.generate
        "Ok"->Console.log
      }
    | Error(e) => {
        `Error: ${e->toString}`->Console.log
        Sys.exit(1)
      }
    }
  )
}

main()
