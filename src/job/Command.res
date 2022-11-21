open Instance
open! Jobt

let getJobs = (ints: array<Instance.t>) => {
  ints
  ->Array.filter(int => int.mode == #command)
  ->Array.flatMap(({
    name,
    image,
    version,
    folder,
    beforeScript,
    script,
    afterScript,
    needs,
    cache,
    profiles,
    rules,
  }) => {
    profiles->Array.map(profile =>
      {
        `Found command instance: ${name}/${version} (${profile})`->Console.log
        switch image {
        | Some(image) => Ok(image)
        | _ =>
          profile->Profile.getImage(
            Env.get("CONAN_DOCKER_REGISTRY"),
            Env.get("CONAN_DOCKER_PREFIX"),
          )
        }
      }->Result.map(image => (
        `${name}/${version}`,
        {
          ...Jobt.default,
          before_script: Some([`cd $CI_PROJECT_DIR/${folder}`]->Array.concat(beforeScript)),
          script: Some([`cd $CI_PROJECT_DIR/${folder}`]->Array.concat(script)),
          after_script: Some([`cd $CI_PROJECT_DIR/${folder}`]->Array.concat(afterScript)),
          image: Some(image),
          needs: Some(needs->Array.uniq),
          cache: cache,
          variables: Some([("GIT_SUBMODULE_STRATEGY", "recursive")]->Dict.fromArray),
          rules: rules,
        },
      ))
    )
  })
  ->Result.seq
  ->Task.fromResult
}
