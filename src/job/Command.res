open Instance
open! Jobt

let getJobs = (ints: array<Instance.t>) => {
  ints
  ->Array.filter(int => int.mode == #command)
  ->Array.flatMap(({name, image, version, folder, beforeScript, script, afterScript, needs, cache, profiles}) => {
    profiles->Array.map(profile =>
      switch image {
      | Some(image) => Ok(image)
      | _ =>
        profile->Profile.getImage(Env.get("CONAN_DOCKER_REGISTRY"), Env.get("CONAN_DOCKER_PREFIX"))
      }->Result.map(image => (
        `${name}/${version}`,
        {
          ...Jobt.default,
          before_script: Some([`cd ${folder}`]->Array.concat(beforeScript)),
          script: Some([`cd ${folder}`]->Array.concat(script)),
          after_script: Some([`cd ${folder}`]->Array.concat(afterScript)),
          image: Some(image),
          needs: Some(needs->Array.uniq),
          cache: cache,
        },
      ))
    )
  })
  ->Result.seq
  ->Task.fromResult
}
