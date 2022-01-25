type t = {
  name: string,
  //version: string;
  extends: option<array<string>>,
  variables: option<Js.Dict.t<string>>,
  image: option<string>,
  tags: option<array<string>>,
  script: option<array<string>>,
  needs: array<string>,
  services: option<array<string>>
  //mode: JobMode;
}