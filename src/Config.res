let name = "devops.yml"

let rec find = dir => {
  let path = Path.join([dir, name])
  switch dir {
  | _ if File.exists(path) => Some(path)
  | "." => None
  | _ => find(Path.dirname(dir))
  }
}

let load = (content, path) => content->Yaml.parse->Yaml.map(Instance.create(_, path->Path.dirname))

let loadFile = path => path->File.read->Result.map(v => load(v, path))
