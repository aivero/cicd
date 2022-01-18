type set = {
  set: string,
  val: string,
}

type opt = {
  opt: string,
  val: string,
}

type t = {
  name: option<string>,
  version: option<string>,
  commit: option<string>,
  branch: option<string>,
  folder: option<string>,
  cmdsPre: option<array<string>>,
  cmds: option<array<string>>,
  cmdsPost: option<array<string>>,
  image: option<string>,
  tags: option<array<string>>,
  mode: option<string>,
  req: option<array<string>>,
  revReq: option<array<string>>,
  // Conan
  profiles: option<array<string>>,
  settings: option<Js.Dict.t<string>>,
  options: option<Js.Dict.t<string>>,
  bootstrap: option<bool>,
  debugPkg: option<bool>,
  // Docker
  conanInstall: option<array<string>>,
  subdir: option<string>,
  script: option<array<string>>,
  tag: option<string>,
  platform: option<string>,
  dockerfile: option<string>,
}

let empty: t = {
  name: None,
  version: None,
  commit: None,
  branch: None,
  folder: None,
  cmdsPre: None,
  cmds: None,
  cmdsPost: None,
  image: None,
  tags: None,
  mode: None,
  req: None,
  revReq: None,
  // Conan
  profiles: None,
  settings: None,
  options: None,
  bootstrap: None,
  debugPkg: None,
  // Docker
  conanInstall: None,
  subdir: None,
  script: None,
  tag: None,
  platform: None,
  dockerfile: None,
}

let validate = (conf: t) =>
  switch conf.profiles {
  | Some(profiles) => profiles->Js.Array.length > 0 ? Ok(conf) : Error("Empty profiles")
  | None => Error("No profiles")
  }

let create = (folderPath, int: Js.Nullable.t<t>) => {
  let int = switch Js.Nullable.toOption(int) {
  | Some(int) => int
  | None => empty
  }
  let int = {
    ...int,
    name: switch int.name {
    | Some(name) => Some(name)
    | None => Some(Path.basename(folderPath))
    },
    commit: switch int.commit {
    | Some(commit) => Some(commit)
    | None => Env.get("CI_COMMIT_SHA")
    },
    version: switch int.version {
    | Some(version) => Some(version)
    | None => Env.get("CI_COMMIT_SHA")
    },
    branch: switch int.branch {
    | Some(branch) => Some(branch)
    | None => Env.get("CI_COMMIT_REF_NAME")
    },
    profiles: switch int.profiles {
    | Some(profiles) => Some(profiles)
    | None => Some(["linux-x86_64", "linux-armv8"])
    },
    folder: switch int.folder {
    | Some(folder) => Some(Path.join([folderPath, folder]))
    | None => Some(folderPath)
    },
  }->validate
  int
}

type mode = [
  | #conan
  | #docker
  | #command
  | #"conan-install-tarball"
  | #"conan-install-script"
]

type zip = {
  int: t,
  profile: string,
  mode: mode
}

let parseMode = str => {
  switch str {
  | "conan" => #conan
  | "docker" => #docker
  | "conan-install-tarball" => #"conan-install-tarball"
  | "conan-install-script" => #"conan-install-script"
  | _ => #command
  }
}

let getMode = (int: t) => {
  switch (int.mode, int.folder) {
  | (Some(mode), _) => parseMode(mode)
  | (_, Some(folder)) if File.exists(Path.join([folder, "conanfile.py"])) => #conan
  | (_, Some(folder)) if File.exists(Path.join([folder, "Dockerfile"])) => #docker
  | (_, _) => #command
  }
}

let zip = ints =>
    ints
    ->Array.map(int =>
      switch int.profiles {
      | Some(profiles) => Ok(profiles->Array.map(profile => {int: int, profile: profile, mode: int->getMode }))
      | None => Error("No profiles")
      }
    )
    ->Seq.array
    ->Result.map(Array.concatMany)
