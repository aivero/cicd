open Instance
open! Jobt

type commandInstance = {
  base: Instance.t,
  extends: array<string>,
  hash: string,
}

let getJobs = (ints: array<Instance.t>) => {
  ints
  ->Array.filter(int => int.mode == #command)
  ->Array.flatMap(({ name, version, folder, script, needs, cache, profiles }) => {
    profiles->Array.map(profile => {
      profile
      ->Profile.getImage
      ->Result.map(image => (
        `${name}/${version}`,
        {
          script: Some([`cd ${folder}`]->Array.concat(script)),
          image: Some(image),
          tags: None,
          variables: None,
          extends: None,
          services: None,
          needs: needs->Array.uniq,
          cache: cache,
        },
      ))
    })
  })
  ->Result.seq
  ->Task.fromResult
}
