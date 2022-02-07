type cache = {
  key: option<string>,
  paths: array<string>
}

type t = {
  extends: option<array<string>>,
  variables: option<Dict.t<string>>,
  image: option<string>,
  tags: option<array<string>>,
  script: option<array<string>>,
  needs: array<string>,
  services: option<array<string>>,
  cache: option<cache>
}
