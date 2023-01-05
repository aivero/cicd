type cache = {
  key: option<string>,
  paths: array<string>,
}

type retry = {
  max: option<int>,
  \"when": option<array<string>>,
}

type artifacts = {
  expire_in: option<string>,
  paths: option<array<string>>,
  \"when": option<string>,
}

type rule = {
  \"if": option<string>,
  \"when": option<string>,
}

type t = {
  extends: option<array<string>>,
  variables: option<Dict.t<string>>,
  image: option<string>,
  tags: option<array<string>>,
  before_script: option<array<string>>,
  script: option<array<string>>,
  after_script: option<array<string>>,
  needs: option<array<string>>,
  services: option<array<string>>,
  cache: option<cache>,
  retry: option<retry>,
  artifacts: option<artifacts>,
  \"when": option<string>,
  allow_failure: option<bool>,
  rules: option<array<rule>>,
  interruptible: bool,
}

let default = {
  extends: None,
  image: None,
  tags: None,
  needs: None,
  services: None,
  variables: None,
  before_script: None,
  script: None,
  after_script: None,
  cache: None,
  retry: None,
  artifacts: None,
  \"when": None,
  allow_failure: None,
  rules: None,
  interruptible: true,
}
