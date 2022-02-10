open Instance
open! Jobt

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
          ...Jobt.default,
          script: Some([`cd ${folder}`]->Array.concat(script)),
          image: Some(image),
          needs: Some(needs->Array.uniq),
          cache: cache,
        },
      ))
    })
  })
  ->Result.seq
  ->Task.fromResult
}
