@send external toString: 'a => string = "toString"

let main = () => {
  let _ = Mode.load()->Task.flatMap(res =>
    switch res {
    | Ok(val) => {
        val->Gitlab.generate
        "Ok"->Js.Console.log->Task.resolve
      }
    | Error(e) => {
      `Error: ${e->toString}`->Js.Console.log
      Proc.exit(1)->Task.resolve
    } 
    }
  )
}

main()
