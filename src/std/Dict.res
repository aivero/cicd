type t<'a> = Js.Dict.t<'a>

let entries = Js.Dict.entries
let fromArray = Js.Dict.fromArray
let get = Js.Dict.get

let map = d => d->entries->Array.map