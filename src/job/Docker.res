open Job_t
open Instance

type dockerInstance = {
  name: string,
  file: string,
  folder: string,
  tags: array<string>,
  reqs: array<string>,
}

let getName = (file, folder) => {
  switch (file->String.split("."))[0] {
  | Some("Dockerfile") => folder->Path.basename
  | Some(name) => name
  | _ => folder->Path.basename
  }
}

let getTags = name => {
  name->String.includes("armv8") ? ["x86_64", "aws"] : ["armv8", "aws"]
}

let getInstances = ({name, folder, modeInt, tags, reqs}: Instance.t): array<dockerInstance> => {
  let file = switch modeInt->Yaml.get("file") {
  | Yaml.String(file) => Some(file)
  | _ => None
  }
  switch file {
  | Some(file) => [{name: name, file: file, folder: folder, tags: tags, reqs: reqs}]
  | None =>
    Path.read(folder)
    ->Array.filter(file => file.name->String.includes("Dockerfile"))
    ->Array.map(file => {
      name: getName(file.name, folder),
      file: file.name,
      folder: folder,
      tags: name->getTags,
      reqs: reqs,
    })
  }
}

let getJob = ({name, file, folder, tags, reqs}: dockerInstance) => {
  switch (
    Env.get("DOCKER_USER"),
    Env.get("DOCKER_PASSWORD"),
    Env.get("DOCKER_REGISTRY"),
    Env.get("DOCKER_PREFIX"),
  )->Option.seq4 {
  | Some(env) => Ok(env)
  | None => Error("Docker: Username, password, registry or prefix not provided!")
  }->Result.map(((username, password, registry, prefix)) => {
    let dockerTag = `${registry}${prefix}${name}`
    let script = [
      `docker login --username ${username} --password ${password} ${registry}`,
      `docker build ${folder} --file ${[folder, file]->Path.join} --tag ${dockerTag}`,
      `docker push ${dockerTag}`,
    ]
    {
      name: name,
      script: Some(script),
      image: Some("docker:19.03.12"),
      services: Some(["docker:19.03.12-dind"]),
      tags: Some(tags),
      extends: None,
      variables: None,
      needs: reqs,
    }
  })
}

let getJobs = (ints: array<Instance.t>) => {
  let ints = ints->Array.flatMap(getInstances)
  ints->Array.map(getJob)->Result.seq->Task.resolve
}
