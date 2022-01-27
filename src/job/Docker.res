open Job_t

type dockerInstance = {
  name: string,
  file: string,
  folder: string,
  tags: array<string>,
  needs: array<string>,
}

let getName = (file, folder) => {
  switch (file->String.split("."))[0] {
  | Some("Dockerfile") => folder->Path.basename
  | Some(name) => name
  | _ => folder->Path.basename
  }
}

let getInstances = ({name, folder, modeInt, tags, needs}: Instance.t): array<dockerInstance> => {
  let file = switch modeInt->Yaml.get("file") {
  | Yaml.String(file) => Some(file)
  | _ => None
  }
  switch file {
  | Some(file) => [{name: name, file: file, folder: folder, tags: tags, needs: needs}]
  | None =>
    Path.read(folder)
    ->Array.filter(file => file.name->String.includes("Dockerfile"))
    ->Array.map(file => {
      name: getName(file.name, folder),
      file: file.name,
      folder: folder,
      tags: ["gitlab-org-docker"],
      needs: needs,
    })
  }
}

let getJob = ({name, file, folder, tags, needs}: dockerInstance) => {
  ("DOCKER_USER", "DOCKER_PASSWORD", "DOCKER_REGISTRY", "DOCKER_PREFIX")
  ->Tuple.map4(Env.getError)
  ->Result.seq4
  ->Result.map(((username, password, registry, prefix)) => {
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
      needs: needs,
    }
  })
}

let getJobs = (ints: array<Instance.t>) =>
  ints->Array.flatMap(getInstances)->Array.map(getJob)->Result.seq->Task.resolve
