open Jobt

let rec chunk = (array, size) => {
  let cur = array->Array.slice(~offset=0, ~len=size)
  let rest = array->Array.slice(~offset=size, ~len=array->Array.length - size)
  switch rest->Array.length {
  | 0 => [cur]
  | _ => [cur]->Array.concat(rest->chunk(size))
  }
}

let generate = jobs => {
  let encode = Encoder.new()->Encoder.encode
  let jobs =
    jobs->Array.empty
      ? [
          (
            "empty",
            {
              ...Jobt.default,
              script: Some(["echo"]),
              tags: Some(["x86_64"]),
            },
          ),
        ]
      : jobs
  jobs
  ->Dict.fromArray
  ->Yaml.classify
  ->Yaml.stringify
  ->encode
  ->File.write("generated-config.yml")
}
