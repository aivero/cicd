type t = {
  name: string,
  extends: option<array<string>>,
  variables: option<Dict.t<string>>,
  image: option<string>,
  tags: option<array<string>>,
  script: option<array<string>>,
  needs: array<string>,
  services: option<array<string>>,
}
