open Instance
open! Jobt

let getJobs = (ints: array<Instance.t>) => {
  ints
  ->Array.filter(int => int.mode == #command)
  ->Array.flatMap(({name, version, image, script, needs, profiles, folder}) => {
    profiles
    ->Array.map(profile =>
      Dict.to(
        `${name}/${version}-${profile}`,
        {
          script: Some([`cd ${folder}`]->Array.concat(script)),
          image: profile->Profile.getImage(image),
          tags: None,
          variables: None,
          extends: None,
          services: None,
          needs: needs->Array.uniq,
        },
      )
    )
    ->Array.concat([
      Dict.to(
        `${name}/${version}`,
        {
          script: Some(["echo"]),
          image: None,
          tags: None,
          variables: None,
          extends: None,
          services: None,
          needs: profiles->Array.map(profile => `${name}/${version}-${profile}`),
        },
      ),
    ])
  })
  ->Task.to
}
