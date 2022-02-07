open Jobt

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
    CARGO_HOME: "$CI_PROJECT_DIR/.cargo"
    SCCACHE_DIR: "$CI_PROJECT_DIR/.sccache"
    GIT_CLEAN_FLAGS: -x -f -e $CARGO_HOME/** -e $SCCACHE_DIR/** -e $CONAN_DATA_PATH/**
  script:
    - conan config install $CONAN_CONFIG_URL -sf $CONAN_CONFIG_DIR
    - conan config set general.default_profile=$PROFILE
    - conan config set storage.path=$CONAN_DATA_PATH
    - conan user $CONAN_LOGIN_USERNAME -p $CONAN_LOGIN_PASSWORD -r $CONAN_REPO_ALL
    - conan user $CONAN_LOGIN_USERNAME -p $CONAN_LOGIN_PASSWORD -r $CONAN_REPO_INTERNAL
    - conan user $CONAN_LOGIN_USERNAME -p $CONAN_LOGIN_PASSWORD -r $CONAN_REPO_PUBLIC
    - conan remove --locks
    - conan create -u $FOLDER $NAME/$VERSION@ $ARGS
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
    - key: $CI_PIPELINE_ID
      paths:
        - $CONAN_DATA_PATH
    - key: $CI_RUNNER_EXECUTABLE_ARCH
      paths:
        - $CARGO_HOME
        - $SCCACHE_DIR
.conan-x86_64:
  extends: .conan
  tags: [x86_64,aws]
  image: registry.gitlab.com/aivero/open-source/contrib/focal-x86_64-dockerfile:master
.conan-armv8:
  extends: .conan
  tags: [armv8,aws]
  image: registry.gitlab.com/aivero/open-source/contrib/focal-armv8-dockerfile:master
.conan-x86_64-bootstrap:
  extends: .conan-x86_64
  image: registry.gitlab.com/aivero/open-source/contrib/focal-x86_64-bootstrap-dockerfile:master
.conan-armv8-bootstrap:
  extends: .conan-armv8
  image: registry.gitlab.com/aivero/open-source/contrib/focal-armv8-bootstrap-dockerfile:master
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
              cache: None,
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
