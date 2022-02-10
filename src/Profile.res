type t = {int: Instance.t, profile: string}

let default = "linux-x86_64"

let getImage = (profile) => {
  let (registry, prefix) = (Env.getError("DOCKER_REGISTRY"), Env.getError("DOCKER_PREFIX"))

  let triple = profile->String.split("-")->List.fromArray
  let os = switch triple {
  | list{_, "musl", ..._} => Ok("alpine")
  | list{"linux", ..._} | list{"wasi", ..._} => Env.getError("DOCKER_DISTRO")
  | list{"windows", ..._} => Ok("windows")
  | list{"macos", ..._} => Ok("macos")
  | _ => Error(`profile: os in ${profile} not supported`)
  }

  let arch = switch triple {
  | list{_, "x86_64", ..._} | list{_, "wasm", ..._} => Ok("x86_64")
  | list{_, "armv8", ..._} => Ok("armv8")
  | _ => Error(`profile: arch in ${profile} not supported`)
  }

  (registry, prefix, os, arch)->Result.seq4->Result.map(((registry, prefix, os, arch)) => `${registry}${prefix}${os}-${arch}`)
}

let getTags = (profile) => {
  
  let triple = profile->String.split("-")->List.fromArray
  let arch = switch triple {
  | list{_, "x86_64", ..._} | list{_, "wasm", ..._} => Ok("x86_64")
  | list{_, "armv8", ..._} => Ok("armv8")
  | _ => Error(`profile: arch in ${profile} not supported`)
  }

  arch->Result.map(arch => [arch, "aws"])
}