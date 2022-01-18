let name = "devops.yml"

type t = option<array<Js.Nullable.t<Instance.t>>>

let rec find = dir => {
  let path = Path.join([dir, name])
  switch dir {
  | _ if File.exists(path) => Some(path)
  | "." => None
  | _ => find(Path.dirname(dir))
  }
}

external toConfig: Yaml.t => t = "%identity"

let load = (content, path) => {
  switch content->Yaml.parse->toConfig {
  | Some(conf) => conf->Array.map(path->Path.dirname->Instance.create)
  | None => []
  }
}

let loadFile = path => path->File.read->Result.flatMap(content => content->load(path)->Seq.result)
  