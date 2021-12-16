@send external toString: 'a => string = "toString"

let main = () => {
  let _ = Mode.load()->Task.map(res =>
    switch res {
    | Ok(val) => {
        val->Gitlab.generate
        "Ok"->Js.Console.log
      }
    | Error(e) => {
      `Error: ${e->toString}`->Js.Console.log
      Proc.exit(1)
    } 
    }
  )
}

main()
