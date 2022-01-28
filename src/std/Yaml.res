type rec t =
  | String(string)
  | Number(float)
  | Object(Dict.t<t>)
  | Array(array<t>)
  | Bool(bool)
  | Null

@val external _internalClass: 'a => string = "Object.prototype.toString.call"
external _asBool: 'a => bool = "%identity"
external _asString: 'a => string = "%identity"
external _asFloat: 'a => float = "%identity"
external _asArray: 'a => array<t> = "%identity"
external _asDict: 'a => Dict.t<t> = "%identity"

let rec classify = value => {
  switch _internalClass(value) {
  | "[object Boolean]" => Bool(_asBool(value))
  | "[object Null]" | "[object Undefined]" => Null
  | "[object String]" => String(_asString(value))
  | "[object Number]" => Number(_asFloat(value))
  | "[object Array]" => Array(_asArray(value)->Array.map(elem => elem->classify))
  | _ => Object(_asDict(value)->Dict.map(((key, val)) => (key, val->classify))->Dict.fromArray)
  }
}

let get = (yaml: t, key) =>
  switch yaml {
  | Object(dict) =>
    switch dict->Dict.get(key) {
    | Some(val) => val
    | None => Null
    }
  | _ => Null
  }

let map = (yml, f) =>
  switch yml {
  | Array(array) => array->Array.map(f)
  | _ => []
  }

@module("yaml") external _parse: string => t = "parse"
let parse = string => string->_parse->classify

let rec _stringify = (yml, level) =>
  switch yml {
  | String(string) => `"${string}"`
  | Number(float) => float->Float.toString
  | Object(obj) =>
    (level != 0 ? "\n" : "") ++
    obj
    ->Dict.entries
    ->Array.map(((key, val)) =>
      `${"  "->String.repeat(level)}${key}: ${val->_stringify(level + 1)}`
    )
    ->Array.join("\n")
  | Array(array) =>
    (level != 0 ? "\n" : "") ++
    array
    ->Array.map(val => `${"  "->String.repeat(level)}- ${val->_stringify(level + 1)}`)
    ->Array.join("\n")
  | Bool(bool) => bool ? "true" : "false"
  | Null => ""
  }

let stringify = yml => _stringify(yml, 0)
