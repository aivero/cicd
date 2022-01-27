type t = {int: Instance.t, profile: string}

let getImage = (profile, image) => {
  let base = Env.get("CICD_DOCKER_BASE")

  let triple = profile->String.split("-")->List.fromArray
  let os = switch triple {
  | list{_, "musl", ..._} => Some("alpine")
  | list{"linux", ..._} | list{"wasi", ..._} => Env.get("CICD_DOCKER_DISTRO")
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
  | None => (base, os, arch)->Option.seq3->Option.map(((base, os, arch)) => `${base}${os}-${arch}`)
  }
}