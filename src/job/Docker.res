open! Jobt

type dockerInstance = {
  name: string,
  version: string,
  profile: string,
  file: string,
  folder: string,
  tags: array<string>,
  needs: array<string>,
  image: option<string>,
  params: option<array<string>>,
  beforeScript: array<string>,
  script: array<string>,
  afterScript: array<string>,
  \"when": option<string>,
  allow_failure: option<bool>,
}

let getInstances = (
  {
    name,
    version,
    folder,
    profiles,
    tags,
    needs,
    image,
    modeInt,
    beforeScript,
    script,
    afterScript,
    manual,
  }: Instance.t,
): array<dockerInstance> => {
  let file = switch modeInt->Yaml.get("file") {
  | Yaml.String(file) => Some(file)
  | _ => None
  }
  let params = switch modeInt->Yaml.get("params") {
  | Yaml.Array(params) => Some(params->Array.reduce((params, p) =>
        switch p {
        | Yaml.String(p) => params->Array.concat([p])
        | _ => params
        }
      , []))
  | _ => None
  }
  let (\"when", allow_failure) = switch manual {
  | Some(true) => (Some("manual"), Some(false))
  | _ => (None, None)
  }
  profiles->Array.flatMap(profile =>
    switch file {
    | Some(file) => [
        {
          name: name,
          version: version,
          profile: profile,
          file: file,
          folder: folder,
          tags: tags,
          needs: needs,
          image: image,
          params: params,
          beforeScript: beforeScript,
          script: script,
          afterScript: afterScript,
          \"when": \"when",
          allow_failure: allow_failure,
        },
      ]
    | None =>
      Path.read(folder)
      ->Array.filter(file => file.name->String.includes("Dockerfile"))
      ->Array.map(file => {
        name: switch (file.name->String.split("."))[0] {
        | Some("Dockerfile") => name
        | Some(name) => name
        | _ => name
        },
        version: version,
        profile: profile,
        file: file.name,
        folder: folder,
        tags: ["gitlab-org-docker"],
        needs: needs,
        image: image,
        params: params,
        beforeScript: beforeScript,
        script: script,
        afterScript: afterScript,
        \"when": \"when",
        allow_failure: allow_failure,
      })
    }
  )
}

let getJob = (
  {
    name,
    version,
    profile,
    file,
    folder,
    tags,
    needs,
    image,
    params,
    beforeScript,
    script,
    afterScript,
    \"when",
    allow_failure,
  }: dockerInstance,
) => {
  `Found docker instance: ${name}/${version} (${profile})`->Console.log
  ("DOCKER_USER", "DOCKER_PASSWORD", "DOCKER_REGISTRY", "DOCKER_PREFIX")
  ->Tuple.map4(Env.getError)
  ->Result.seq4
  ->Result.flatMap(((username, password, registry, prefix)) => {
    let dockerTag = `${registry}${prefix}${name}/${profile}`
    let branchTagUpload = switch version->String.match(%re("/^[0-9a-f]{40}$/")) {
    | Some(_) => true
    | _ => false
    }
    let latestTagUpload = switch Env.get("CI_COMMIT_REF_NAME") {
    | Some("master") => true
    | _ => false
    }
    let image = switch image {
    | Some(image) => {
        Console.log("Docker Mode: Image is set, using it as docker image")
        Some(image)
      }
    | _ => {
        Console.log("Docker Mode: Image is not set, using default docker:20")
        Some("docker:20")
      }
    }
    let tags = switch tags->Array.empty {
    | false => {
        Console.log("Docker Mode: Tags are set, overriding profile-generated tags")
        Some(tags)
      }
    | true => profile->Profile.getTags->Result.toOption
    }
    let dockerParams = switch params {
    | Some(pa) => pa->Array.join(" ")
    | _ => {
        Console.log("Docker Mode: params are NOT set")
        ""
      }
    }

    profile
    ->Profile.getPlatform
    ->Result.map(platform => {
      let script = switch script->Array.empty {
      | true =>
        [
          "docker login -u $CI_DEPENDENCY_PROXY_USER -p $CI_DEPENDENCY_PROXY_PASSWORD $CI_DEPENDENCY_PROXY_SERVER",
          `docker login --username ${username} --password ${password} ${registry}`,
          `docker build . --file ${file} --platform ${platform} ${dockerParams} --tag ${dockerTag}:${version}`,
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
      | false => script
      }
      (
        `${name}/${version}`,
        {
          ...Jobt.default,
          before_script: Some([`cd $CI_PROJECT_DIR/${folder}`]->Array.concat(beforeScript)),
          script: Some([`cd $CI_PROJECT_DIR/${folder}`]->Array.concat(script)),
          after_script: Some([`cd $CI_PROJECT_DIR/${folder}`]->Array.concat(afterScript)),
          image: image,
          services: Some(["docker:20-dind"]),
          tags: tags,
          needs: Some(needs->Array.concat(["conan-upload"])->Array.uniq),
          variables: Some(
            Dict.fromArray([
              ("DOCKER_TLS_CERTDIR", "/certs"),
              ("GIT_SUBMODULE_STRATEGY", "recursive"),
            ]),
          ),
          \"when": \"when",
          allow_failure: allow_failure,
        },
      )
    })
  })
}

let getJobs = (ints: array<Instance.t>) =>
  ints
  ->Array.filter(int => int.mode == #docker)
  ->Array.flatMap(int => int->getInstances->Array.map(getJob))
  ->Result.seq
  ->Task.fromResult
