type t = {int: Instance.t, profile: string}

let default = "linux-x86_64"

let getImage = (profile, registry: option<string>, prefix) => {
  let registry =
    registry
    ->Option.flatFold(() => Env.get("DOCKER_REGISTRY"))
    ->Option.toResult("DOCKER_REGISTRY not defined")
  let prefix =
    prefix
    ->Option.flatFold(() => Env.get("DOCKER_PREFIX"))
    ->Option.toResult("DOCKER_PREFIX not defined")

  let triple = profile->String.split("-")->List.fromArray
  let os = switch triple {
  | list{_, "musl", ..._} => Ok("alpine")
  | list{"linux", ..._} | list{"wasi", ..._} => Env.getError("DOCKER_DISTRO")
  | list{"windows", ..._} => Ok("windows")
  | list{"macos", ..._} => Ok("macos")
  | _ => Error(`profile: os in ${profile} not supported`)
  }

  (registry, prefix, os)
  ->Result.seq3
  ->Result.map(((registry, prefix, os)) => `${registry}${prefix}${os}/${profile}`)
}

let getPlatform = profile => {
  let triple = profile->String.split("-")->List.fromArray
  let os = switch triple {
  | list{"linux", ..._} | list{"wasi", ..._} => Ok("linux")
  | list{"windows", ..._} => Error(`Windows builds are not yet supported`)
  | list{"macos", ..._} => Error(`MacOS/Darwin builds are not yet supported`)
  | _ => Error(`profile: os in ${profile} not supported`)
  }

  let arch = switch triple {
  | list{_, "x86_64", ..._} | list{_, "wasm", ..._} => Ok("amd64")
  | list{_, "armv8", ..._} => Ok("arm64")
  | _ => Error(`profile: arch in ${profile} not supported`)
  }

  (os, arch)->Result.seq2->Result.map(((os, arch)) => `${os}/${arch}`)
}

let getTags = profile => {
  let triple = profile->String.split("-")->List.fromArray
  let arch = switch triple {
  | list{_, "x86_64", ..._} | list{_, "wasm", ..._} => Ok("x86_64")
  | list{_, "armv8", ..._} => Ok("armv8")
  | _ => Error(`profile: arch in ${profile} not supported`)
  }

  arch->Result.map(arch => [arch, "aws"])
}
