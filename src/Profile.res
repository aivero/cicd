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



// Parse the profile name to a docker/buildx conform string as per
// https://github.com/docker/buildx#---platformvaluevalue
let getDockerPlatform = profile => {
  let [os, arch] = profile->String.split("-")
  let os = switch os {
  | "linux" => Ok("linux")
  | "windows" => Error("Windows builds are not yet supported")
  | "macos" => Error("MacOS / Darwin builds are not yet supported")
  | _ => Error(`Could not parse profile ${profile} to an os.`)
  }

  let arch = switch arch {
  | "armv8" | "arm64" => Ok("arm64")
  | "arm7" | "armhf" => Ok("arm/v7")
  | "86_64" | "86-64" => Ok("amd64")
  | _ => Error(`Could not parse profile ${profile} to an arch.`)
  }

  (os, arch)->Result.seq2->Result.map(((os, arch)) => `${os} /${arch}`)
}
