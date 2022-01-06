let rec chunk = (array, size) => {
  let cur = array->Array.slice(~offset=0, ~len=size)
  let rest = array->Array.slice(~offset=size, ~len=array->Array.length - size)
  switch rest->Array.length {
  | 0 => [cur]
  | _ => [cur]->Array.concat(rest->chunk(size))
  }
}

let generateJob = (job: Job_t.t) => {
  Array.concatMany([
    [`${job.name}:`, `  needs: [${job.needs->Array.joinWith(", ", a => a)}]`],
    switch job.image {
    | Some(image) => [`  image: ${image}`]
    | None => []
    },
    switch job.extends {
    | Some(extends) => [`  extends: ${extends}`]
    | None => []
    },
    switch job.variables {
    | Some(vars) => ["  variables:"]->Array.concat(vars->Js.Dict.entries->Array.map(((key, val)) => `    ${key}: ${val}`))
    | None => []
    },
    switch job.script {
    | Some(script) => ["  script:"]->Array.concat(script->Array.map(l => `    - ${l}`))
    | None => []
    },
  ])
}

let base = `
.conan:
  script:
    - conan config install $CONAN_CONFIG_URL -sf $CONAN_CONFIG_DIR
    - conan user $CONAN_LOGIN_USERNAME -p $CONAN_LOGIN_PASSWORD -r $CONAN_REPO_ALL
    - conan user $CONAN_LOGIN_USERNAME -p $CONAN_LOGIN_PASSWORD -r $CONAN_REPO_INTERNAL
    - conan user $CONAN_LOGIN_USERNAME -p $CONAN_LOGIN_PASSWORD -r $CONAN_REPO_PUBLIC
    - conan config set general.default_profile=$PROFILE
    - conan create $FOLDER $PKG@ $ARGS
    - conan upload $PKG@ --all -c -r $REPO
  retry:
    max: 2
    when:
      - runner_system_failure
      - stuck_or_timeout_failure
  artifacts:
    expire_in: 1 month
    paths:
      - "*/$PKG/_/_/build/*/meson-logs/*-log.txt"
      - "*/$PKG/_/_/build/*/*/meson-logs/*-log.txt"
      - "*/$PKG/_/_/build/*/CMakeFiles/CMake*.log"
      - "*/$PKG/_/_/build/*/*/CMakeFiles/CMake*.log"
      - "*/$PKG/_/_/build/*/*/config.log"
    when: always
.conan-x86_64:
  extends: .conan
  tags: [x86_64]
  image: aivero/conan:focal-x86_64
.conan-armv8:
  extends: .conan
  tags: [armv8]
  image: aivero/conan:focal-armv8
.conan-x86_64-bootstrap:
  extends: .conan-x86_64
  image: aivero/conan:focal-x86_64-bootstrap
.conan-armv8-bootstrap:
  extends: .conan-armv8
  image: aivero/conan:focal-armv8-bootstrap
`

let generate = (jobs: array<Job_t.t>) => {
  let encode = Encoder.new()->Encoder.encode
  let jobs =
    jobs->Array.length > 0
      ? jobs
      : [{name: "empty", needs: [], script: Some(["echo"]), image: None, extends: None, variables: None}]

  jobs
  ->Array.map(generateJob)
  ->Array.concatMany
  ->Array.joinWith("\n", a => a)
  ->(conf => base ++ conf)
  ->encode
  ->File.write("generated-config.yml")
}
