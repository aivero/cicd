let main = () => {
  Mode.load()->Task.flatMap((res) => Js.Console.log(res)->Task.resolve)->ignore
  //let bla = res->then((a) => Js.log(a)->resolve)
  //let bla = [res]->all

}

main()
//Sys.command("ls");