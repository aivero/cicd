open! Jobt

type dockerInstance = {
  name: string,
  version: string,
  file: string,
  folder: string,
  tags: array<string>,
  needs: array<string>,
  hash: string,
}

let hashLength = 3
let hashN = Hash.hashN(_, hashLength)

let getName = (file, folder) => {
  switch (file->String.split("."))[0] {
  | Some("Dockerfile") => folder->Path.basename
  | Some(name) => name
  | _ => folder->Path.basename
  }
}

let getInstances = (int: Instance.t): array<dockerInstance> => {
  let file = switch int.modeInt->Yaml.get("file") {
  | Yaml.String(file) => Some(file)
  | _ => None
  }
  let hash = int->hashN
  switch file {
  | Some(file) => [
      {
        name: int.name,
        version: int.version,
        file: file,
        folder: int.folder,
        tags: int.tags,
        needs: int.needs,
        hash: hash,
      },
    ]
  | None =>
    Path.read(int.folder)
    ->Array.filter(file => file.name->String.includes("Dockerfile"))
    ->Array.map(file => {
      name: switch (file.name->String.split("."))[0] {
      | Some("Dockerfile") => int.name
      | Some(name) => name
      | _ => int.name
      },
      version: int.version,
      file: file.name,
      folder: int.folder,
      tags: ["gitlab-org-docker"],
      needs: int.needs,
      hash: hash,
    })
  }
}

let getJob = ({name, version, file, folder, tags, needs, hash}: dockerInstance) => {
  ("DOCKER_USER", "DOCKER_PASSWORD", "DOCKER_REGISTRY", "DOCKER_PREFIX")
  ->Tuple.map4(Env.getError)
  ->Result.seq4
  ->Result.map(((username, password, registry, prefix)) => {
    let dockerTag = `${registry}${prefix}${name}`
    let branchTagUpload = switch version->String.match(%re("/^[0-9a-f]{40}$/")) {
    | Some(_) => true
    | _ => false
    }
    let latestTagUpload = switch Env.get("CI_COMMIT_REF_NAME") {
    | Some("master") => true
    | _ => false
    }
    let script =
      [
        `docker login --username ${username} --password ${password} ${registry}`,
        `docker build ${folder} --file ${[folder, file]->Path.join} --tag ${dockerTag}:${version}`,
        `docker push ${dockerTag}:${version}`,
      ]
      ->Array.concat(
        branchTagUpload
          ? [
              `docker tag ${dockerTag}:${version} ${dockerTag}:$CI_COMMIT_REF_NAME`,
              `docker push ${dockerTag}:$CI_COMMIT_REF_NAME`,
            ]
          : [],
      )
      ->Array.concat(
        latestTagUpload
          ? [
              `docker tag ${dockerTag}:${version} ${dockerTag}:latest`,
              `docker push ${dockerTag}:latest`,
            ]
          : [],
      )

    (
      `${name}/${version}@${hash}`,
      {
        script: Some(script),
        image: Some("docker:19.03.12"),
        services: Some(["docker:19.03.12-dind"]),
        tags: Some(tags),
        extends: None,
        variables: None,
        needs: needs,
        cache: None,
      },
    )
  })
}

let getJobs = (ints: array<Instance.t>) =>
  ints
  ->Array.filter(int => int.mode == #docker)
  ->Array.flatMap(int => {
    let ints = int->getInstances
    ints->Array.map(getJob)
  })
  ->Result.seq
  ->Task.fromResult
