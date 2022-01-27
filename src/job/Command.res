open Instance
open Job_t

let getJobs = (ints: array<Instance.t>) => {
  ints
  ->Array.filter(int => int.mode == #command)
  ->Array.flatMap(({name, version, image, script, needs, profiles}) => {
    profiles
    ->Array.map(profile => {
      name: `${name}/${version}-${profile}`,
      script: Some(script),
      image: profile->Profile.getImage(image),
      tags: None,
      variables: None,
      extends: None,
      services: None,
      needs: needs->Array.uniq,
    })
    ->Array.concat([
      {
        name: `${name}/${version}`,
        script: Some(["echo"]),
        image: None,
        tags: None,
        variables: None,
        extends: None,
        services: None,
        needs: profiles->Array.map(profile => `${name}/${version}-${profile}`),
      },
    ])
  })
  ->TaskResult.resolve
}
