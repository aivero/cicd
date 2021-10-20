let name = "devops.yml"

type t = array<Js.Nullable.t<Instance.t>>

let rec find = dir => {
  let path = Path.join([dir, name])
  switch dir {
  | _ if File.exists(path) => Some(path)
  | "." => None
  | _ => find(Path.dirname(path))
  }
}

external toConfig: Yaml.t => t = "%identity"

let load = (content, path) =>
  content->Yaml.parse->toConfig->Array.map(path->Path.dirname->Instance.create)

let loadFile = path => path->File.read->Result.flatMap(content => content->load(path)->Flat.array)
  