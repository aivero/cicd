open! Jobt
open! Webapi.Base64

type dockerInstance = {
  name: string,
  version: string,
  profile: string,
  file: string,
  folder: string,
  tags: array<string>,
  needs: array<string>,
  beforeScript: array<string>,
  afterScript: array<string>,
}

let getName = (file, folder) => {
  switch (file->String.split("."))[0] {
  | Some("Dockerfile") => folder->Path.basename
  | Some(name) => name
  | _ => folder->Path.basename
  }
}

let getInstances = (
  {name, version, folder, profiles, tags, needs, modeInt, beforeScript, afterScript}: Instance.t,
): array<dockerInstance> => {
  let file = switch modeInt->Yaml.get("file") {
  | Yaml.String(file) => Some(file)
  | _ => None
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
          beforeScript: beforeScript,
          afterScript: afterScript,
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
        beforeScript: beforeScript,
        afterScript: afterScript,
      })
    }
  )
}

let getJob = (
  {name, version, profile, file, folder, tags, needs, beforeScript, afterScript}: dockerInstance,
) => {
  `Found docker instance: ${name}/${version} (${profile})`->Console.log
  ("DOCKER_USER", "DOCKER_PASSWORD", "DOCKER_REGISTRY", "DOCKER_PREFIX")
  ->Tuple.map4(Env.getError)
  ->Result.seq4
  ->Result.flatMap(((username, password, registry, prefix)) => {
    let dockerTag = `${registry}${prefix}${name}/${profile}`
    let branchTagUpload = switch version->String.match(%re("/^[0-9a-f]{40}$/")) {
    | Some(_) => ` --destination ${dockerTag}:$CI_COMMIT_REF_NAME`
    | _ => ``
    }
    let latestTagUpload = switch Env.get("CI_COMMIT_REF_NAME") {
    | Some("master") => ` --destination ${dockerTag}:latest `
    | _ => ``
    }
    let tags = switch tags->Array.empty {
    | false => {
        Console.log("Docker Mode: Tags are set, overriding profile-generated tags")
        Some(tags)
      }
    | true => profile->Profile.getTags->Result.toOption
    }
    let b64Creds = String.trim(btoa(`${username}:${password}`))
    profile
    ->Profile.getPlatform
    ->Result.map(platform => {
      let script = [
        `mkdir -p /kaniko/.docker`,
        `echo '{\\\"auths\\\":{\\\"${registry}\\\":{\\\"auth\\\":\\\"${b64Creds}\\\"}}}' > /kaniko/.docker/config.json`,
        `cat /kaniko/.docker/config.json`,
        `/kaniko/executor --context \\\".\\\" --dockerfile \\\"${file}\\\" --customPlatform ${platform} --destination \\\"${dockerTag}:${version}\\\" ${branchTagUpload} ${latestTagUpload} `,
      ]

      (
        `${name}/${version}`,
        {
          ...Jobt.default,
          before_script: Some([`cd $CI_PROJECT_DIR/${folder}`]->Array.concat(beforeScript)),
          script: Some([`cd $CI_PROJECT_DIR/${folder}`]->Array.concat(script)),
          after_script: Some([`cd $CI_PROJECT_DIR/${folder}`]->Array.concat(afterScript)),
          image: Some({name: "gcr.io/kaniko-project/executor:debug", entrypoint: Some([""])}),
          tags: tags,
          needs: Some(needs),
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
