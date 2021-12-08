type t = {
  name: string,
  //version: string;
  image: option<string>,
  //tags: string[];
  script: option<array<string>>,
  needs: array<string>
  //mode: JobMode;
}