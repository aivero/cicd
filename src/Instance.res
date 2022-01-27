type set = {
  set: string,
  val: string,
}

type opt = {
  opt: string,
  val: string,
}

type mode = [
  | #conan
  | #docker
  | #command
]
//| #"conan-install-tarball"
//| #"conan-install-script"

type t = {
  name: string,
  version: string,
  folder: string,
  mode: mode,
  modeInt: Yaml.t,
  commit: option<string>,
  branch: option<string>,
  reqs: array<string>,
  trigger: array<string>,
  bootstrap: bool,
  profiles: array<string>,
  cmdsPre: array<string>,
  cmds: array<string>,
  cmdsPost: array<string>,
  image: option<string>,
  tags: array<string>,
}

let parseMode = str => {
  switch str {
  | "conan" => #conan
  | "docker" => #docker
  | _ => #command
  }
}

let create = (int: Yaml.t, folderPath): t => {
  let name = switch int->Yaml.get("name") {
  | Yaml.String(name) => name
  | _ => Path.basename(folderPath)
  }
  let version = switch (int->Yaml.get("version"), Env.get("CI_COMMIT_SHA")) {
  | (Yaml.String(version), _) => version
  | (Yaml.Number(version), _) => version->Float.toString
  | (_, Some(sha)) => sha
  | _ => "0.0.0"
  }
  let folder = switch int->Yaml.get("folder") {
  | Yaml.String(folder) => Path.join([folderPath, folder])
  | _ => folderPath
  }
  let mode = switch int->Yaml.get("mode") {
  | Yaml.String(mode) => parseMode(mode)
  | _ if File.exists(Path.join([folder, "conanfile.py"])) => #conan
  | _ if Path.read(folder)->Array.some(file => file.name->String.includes("Dockerfile")) => #docker
  | _ => #command
  }
  let modeInt = switch mode {
  | #conan => int->Yaml.get("conan")
  | #docker => int->Yaml.get("docker")
  | _ => Yaml.Null
  }
  let commit = switch int->Yaml.get("commit") {
  | Yaml.String(commit) => Some(commit)
  | _ => Env.get("CI_COMMIT_SHA")
  }
  let branch = switch int->Yaml.get("branch") {
  | Yaml.String(branch) => Some(branch)
  | _ => Env.get("CI_COMMIT_REF_NAME")
  }
  let reqs = switch int->Yaml.get("reqs") {
  | Yaml.Array(reqs) => reqs->Array.reduce((reqs, req) =>
      switch req {
      | Yaml.String(req) => reqs->Array.concat([req])
      | _ => []
      }
    , [])
  | Yaml.String(req) => [req]
  | _ => []
  }
  let trigger = switch int->Yaml.get("trigger") {
  | Yaml.Array(trigger) => trigger->Array.reduce((ints, int) =>
      switch int {
      | Yaml.String(int) => ints->Array.concat([int])
      | _ => []
      }
    , [])
  | Yaml.String(int) => [int]
  | _ => []
  }
  let bootstrap = switch int->Yaml.get("bootstrap") {
  | Yaml.Bool(bool) => bool
  | _ => false
  }
  let image = switch int->Yaml.get("image") {
  | Yaml.String(image) => Some(image)
  | _ => None
  }
  let tags = switch int->Yaml.get("tags") {
  | Yaml.Array(tags) => tags->Array.reduce((tags, tag) =>
      switch tag {
      | Yaml.String(tag) => tags->Array.concat([tag])
      | _ => []
      }
    , [])
  | _ => []
  }
  let profiles = switch int->Yaml.get("profiles") {
  | Array(profiles) => profiles->Array.reduce((array, profile) =>
      switch profile {
      | String(profile) => array->Array.concat([profile])
      | _ => array
      }
    , [])
  | _ => ["linux-x86_64", "linux-armv8"]
  }
  let cmdsPre = switch int->Yaml.get("cmdsPre") {
  | Yaml.Array(cmds) => cmds->Array.reduce((cmds, cmd) =>
      switch cmd {
      | Yaml.String(cmd) => cmds->Array.concat([cmd])
      | _ => []
      }
    , [])
  | _ => []
  }
  let cmds = switch int->Yaml.get("cmds") {
  | Yaml.Array(cmds) => cmds->Array.reduce((cmds, cmd) =>
      switch cmd {
      | Yaml.String(cmd) => cmds->Array.concat([cmd])
      | _ => []
      }
    , [])
  | _ => []
  }
  let cmdsPost = switch int->Yaml.get("cmdsPost") {
  | Yaml.Array(cmds) => cmds->Array.reduce((cmds, cmd) =>
      switch cmd {
      | Yaml.String(cmd) => cmds->Array.concat([cmd])
      | _ => []
      }
    , [])
  | _ => []
  }
  {
    name: name,
    version: version,
    folder: folder,
    mode: mode,
    modeInt: modeInt,
    commit: commit,
    branch: branch,
    reqs: reqs,
    trigger: trigger,
    bootstrap: bootstrap,
    cmdsPre: cmdsPre,
    cmds: cmds,
    cmdsPost: cmdsPost,
    profiles: profiles,
    image: image,
    tags: tags,
  }
}
