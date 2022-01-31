open Job_t

let rec chunk = (array, size) => {
  let cur = array->Array.slice(~offset=0, ~len=size)
  let rest = array->Array.slice(~offset=size, ~len=array->Array.length - size)
  switch rest->Array.length {
  | 0 => [cur]
  | _ => [cur]->Array.concat(rest->chunk(size))
  }
}

let base = `.conan:
  variables:
    CONAN_USER_HOME: "$CI_PROJECT_DIR"
    CONAN_DATA_PATH: "$CI_PROJECT_DIR/conan_data"
    GIT_SUBMODULE_STRATEGY: recursive
    SCCACHE_DIR: "$PWD/sccache"
    CARGO_HOME: "$PWD/cargo"
  script:
    - conan config install $CONAN_CONFIG_URL -sf $CONAN_CONFIG_DIR
    - conan config set general.default_profile=$PROFILE
    - conan config set storage.path=$CONAN_DATA_PATH
    - conan user $CONAN_LOGIN_USERNAME -p $CONAN_LOGIN_PASSWORD -r $CONAN_REPO_ALL
    - conan user $CONAN_LOGIN_USERNAME -p $CONAN_LOGIN_PASSWORD -r $CONAN_REPO_INTERNAL
    - conan user $CONAN_LOGIN_USERNAME -p $CONAN_LOGIN_PASSWORD -r $CONAN_REPO_PUBLIC
    - conan create $FOLDER $NAME/$VERSION@ $ARGS
    - conan upload $NAME/$VERSION@ --all -c -r $REPO
    - "[[ -n $UPLOAD_ALIAS ]] && conan upload $NAME/$CI_COMMIT_REF_NAME@ --all -c -r $REPO || echo"
  retry:
    max: 2
    when:
      - runner_system_failure
      - stuck_or_timeout_failure
  artifacts:
    expire_in: 1 month
    paths:
      - "conan_data/$NAME/$VERSION/_/_/build/*/meson-logs/*-log.txt"
      - "conan_data/$NAME/$VERSION/_/_/build/*/*/meson-logs/*-log.txt"
      - "conan_data/$NAME/$VERSION/_/_/build/*/CMakeFiles/CMake*.log"
      - "conan_data/$NAME/$VERSION/_/_/build/*/*/CMakeFiles/CMake*.log"
      - "conan_data/$NAME/$VERSION/_/_/build/*/*/config.log"
    when: always
  cache:
    paths:
      - $SCCACHE_DIR
      - $CARGO_HOME
.conan-x86_64:
  extends: .conan
  tags: [x86_64,aws]
  image: aivero/conan:focal-x86_64
.conan-armv8:
  extends: .conan
  tags: [armv8,aws]
  image: aivero/conan:focal-armv8
.conan-x86_64-bootstrap:
  extends: .conan-x86_64
  image: aivero/conan:focal-x86_64-bootstrap
.conan-armv8-bootstrap:
  extends: .conan-armv8
  image: aivero/conan:focal-armv8-bootstrap
`

let generate = (jobs) => {
  let encode = Encoder.new()->Encoder.encode
  let jobs =
    jobs->Array.empty
      ? [
          Dict.to(
            "empty",
            {
              needs: [],
              script: Some(["echo"]),
              image: None,
              services: None,
              tags: Some(["x86_64"]),
              extends: None,
              variables: None,
            },
          ),
        ]
      : jobs

  jobs
  ->Dict.flatten
  ->Yaml.classify
  ->Yaml.stringify
  ->(conf => base ++ conf)
  ->encode
  ->File.write("generated-config.yml")
}
