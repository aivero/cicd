
let main = () => {
  Mode.load()
  ->Task.map(jobs => {
    jobs->Gitlab.generate
    "Ok"->Console.log
  })
  ->Task.mapError(msg => {
    `Error: ${msg}`->Console.log
    Sys.exit(1)
  })->ignore
}

main()
