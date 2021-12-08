//type yaml = bool | float // | string | null | yamlArray | YamlRecord

//type yamlArray = array<Yaml>
//type yamlRecord = ;

/*
@scope("JSON") @val
external parseIntoMyData: string => a' = "parse"
*/


//type t

//Type rec kind<'a> =
//  | String: kind<Js_string.t>
//  | Number: kind<float>
//  | Object: kind<Js_dict.t<t>>
//  | Array: kind<array<t>>
//  | Boolean: kind<bool>
//  | Null: kind<Js_types.null_val>
type rec t =
  | String(Js_string.t)
  | Number(float)
  | Object(Js_dict.t<t>)
  | Array(array<t>)
  | Boolean(bool)
  | Null(Js_types.null_val)



//@module("yaml") external _parse: string => t = "parse"
@module("yaml") external parse: string => t = "parse"

/*
let parse = (s) => {
  E.tryCatch(() => yaml.parse(s), F.flow(String, Error))
}
*/

/*
let stringifyYaml = (u) =>
  E.tryCatch(() => {
    yaml.stringify(u)
  }, () => Error("Converting unsupported structure to YAML"))
  */