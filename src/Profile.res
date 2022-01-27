type t = {int: Instance.t, profile: string}

let getImage = (profile, image) => {
  let registry = Env.get("DOCKER_REGISTRY")
  let prefix = Env.get("DOCKER_PREFIX")

  let triple = profile->String.split("-")->List.fromArray
  let os = switch triple {
  | list{_, "musl", ..._} => Some("alpine")
  | list{"linux", ..._} | list{"wasi", ..._} => Env.get("DOCKER_DISTRO")
  | list{"windows", ..._} => Some("windows")
  | list{"macos", ..._} => Some("macos")
  | _ => None
  }

  let arch = switch triple {
  | list{_, "x86_64", ..._} | list{_, "wasm", ..._} => Some("x86_64")
  | list{_, "armv8", ..._} => Some("armv8")
  | _ => None
  }
  switch image {
  | Some(image) => Some(image)
  | None => (registry, prefix, os, arch)->Option.seq4->Option.map(((registry, prefix, os, arch)) => `${registry}${prefix}${os}-${arch}`)
  }
}