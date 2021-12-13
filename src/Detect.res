let getImage = ({int, profile}: Instance.zip) => {
  // Base Conan image
  let base = "aivero/conan:"

  let triple = profile->Js.String2.split("-")->List.fromArray;
  let os = switch triple {
  | list{_, "musl", ..._ } => Ok("alpine")
  | list{"linux", ..._ } | list{"wasi", ..._} => Ok("bionic")
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

  switch (os, arch) {
  | (Ok(os), Ok(arch)) => Ok(`${base}${os}-${arch}${end}`)
  | (Error(err), _) => Error(err)
  | (_, Error(err)) => Error(err)
  }
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

  switch (os, arch) {
  | (Ok(os), Ok(arch)) => Ok(`${os} /${arch}`)
  | (Error(err), _) => Error(err)
  | (_, Error(err)) => Error(err)
  }
};
