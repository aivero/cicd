type t = {
  name: string,
  //version: string;
  extends: option<string>,
  variables: option<Js.Dict.t<string>>,
  image: option<string>,
  //tags: string[];
  script: option<array<string>>,
  needs: array<string>
  //mode: JobMode;
}