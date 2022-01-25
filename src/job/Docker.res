open Job_t
open Instance

type dockerInstance = {name: string, file: string, folder: string, reqs: array<string>}

let getName = (file, folder) => {
  switch (file->Js.String2.split("."))[0] {
  | Some("Dockerfile") => folder->Path.basename
  | Some(name) => name
  | _ => folder->Path.basename
  }
}

let getInstances = ({name, folder, modeInt, reqs}: Instance.t): array<dockerInstance> => {
  let file = switch modeInt->Yaml.get("file") {
  | Yaml.String(file) => Some(file)
  | _ => None
  }
  switch file {
  | Some(file) => [{name: name, file: file, folder: folder, reqs: reqs}]
  | None =>
    Path.read(folder)
    ->Js.Array2.filter(file => file.name->Js.String2.includes("Dockerfile"))
    ->Array.map(file => {
      name: getName(file.name, folder),
      file: file.name,
      folder: folder,
      reqs: reqs,
    })
  }
}

let getJob = ({name, file, folder, reqs}: dockerInstance) => {
  switch (
    Env.get("DOCKER_USER"),
    Env.get("DOCKER_PASSWORD"),
    Env.get("DOCKER_PREFIX"),
  )->Seq.option3 {
  | Some(env) => Ok(env)
  | None => Error("Docker: Username, password or prefix not provided!")
  }->Result.map(((username, password, prefix)) => {
    let dockerTag = `${prefix}${name}`
    let script = [
      `docker login --username ${username} --password ${password}`,
      `docker build --file ${[folder, file]->Path.join} --tag ${dockerTag}`,
      `docker push ${dockerTag}`,
    ]
    {
      name: name,
      script: Some(script),
      image: Some("docker:19.03.12"),
      services: Some(["docker:19.03.12-dind"]),
      tags: None,
      extends: None,
      variables: None,
      needs: reqs,
    }
  })
}

let getJobs = (ints: array<Instance.t>) => {
  let ints = ints->Array.map(getInstances)->Flat.array
  ints->Array.map(getJob)->Seq.result->Task.resolve
}
