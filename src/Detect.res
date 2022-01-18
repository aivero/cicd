let getImage = ({int, profile}: Instance.zip) => {
  // Base Conan image
  let base = "aivero/conan:"

  let triple = profile->Js.String2.split("-")->List.fromArray;
  let os = switch triple {
  | list{_, "musl", ..._ } => Ok("alpine")
  | list{"linux", ..._ } | list{"wasi", ..._} => Ok("focal")
  | list{"windows", ..._ }  => Ok("windows")
  | list{"macos", ..._ } => Ok("macos")
  | _ => Error(`Could not detect image os for profile: ${profile}`)
  }

  let arch = switch triple {
  | list{_, "x86_64", ..._ } | list{_, "wasm", ..._ } => Ok("x86_64")
  | list{_, "armv8", ..._ } => Ok("armv8")
  | _ => Error(`Could not detect image arch for profile: ${profile}`)
  }

  let end = switch int.bootstrap {
  | Some(true) => "-bootstrap"
  | _ => ""
  }

  Seq.result2(os, arch)->Result.map(((os, arch)) => `${base}${os}-${arch}${end}`) 
}

let getExtends = ({int, profile}: Instance.zip) => {
  let base = ".conan"

  let triple = profile->Js.String2.split("-")->List.fromArray;

  let arch = switch triple {
  | list{_, "x86_64", ..._ } | list{_, "wasm", ..._ } => Ok("x86_64")
  | list{_, "armv8", ..._ } => Ok("armv8")
  | _ => Error(`Could not detect image arch for profile: ${profile}`)
  }

  let end = switch int.bootstrap {
  | Some(true) => "-bootstrap"
  | _ => ""
  }

  arch->Result.map(arch => `${base}-${arch}${end}`)
}


let getRunnerTags = (profile) => {
  let [_, arch] = profile->Js.String2.split("-")
  switch arch {
  | "x86_64" | "wasm" => Ok(["X64", "aws"])
  | "armv8" => Ok(["ARM64", "aws"])
  | _ => Error(`Could detect runner tags for profile: ${profile}`)
  }
};

// Parse the profile name to a docker/buildx conform string as per
// https://github.com/docker/buildx#---platformvaluevalue
let getDockerPlatform = (profile) => {
  let [os, arch] = profile->Js.String2.split("-")
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

  Seq.result2(os, arch)->Result.map(((os, arch)) => `${os} /${arch}`) 
};
