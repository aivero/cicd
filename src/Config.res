let name = "devops.yml"

//type t = option<array<Js.Nullable.t<Instance.t>>>

//type t = Js.Dict.t<string>

let rec find = dir => {
  let path = Path.join([dir, name])
  switch dir {
  | _ if File.exists(path) => Some(path)
  | "." => None
  | _ => find(Path.dirname(dir))
  }
}

//external toConfig: Yaml.t => t = "%identity"

let load = (content, path) => content->Yaml.parse->Yaml.map(Instance.create(_, path->Path.dirname))


let loadFile = (path) => path->File.read->Result.map(v => load(v, path))
  