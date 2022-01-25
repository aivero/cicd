open Instance
open Job_t

type cmdInstance = {
  base: Instance.t,
  profile: string,
}

let getInstances = (int: Instance.t) => {
  let image = Some("") //name->Profile.getImage
  Ok(int.profiles->Array.map(profile => {base: int, profile: profile}))
}

let getJobs = (ints: array<Instance.t>) => {
  ints
  ->Array.filter(int => int.mode == #command)
  ->Array.map(getInstances)
  ->Result.seq
  ->Result.flatMap(ints => {
    let ints = ints->Array.flatten
    ints
    ->Array.map(({base: {name, image, cmds, reqs}, profile}) => Ok({
      name: `${name}-${profile}`,
      script: Some(cmds),
      image: image,
      tags: None,
      variables: None,
      extends: None,
      services: None,
      needs: reqs->Array.map(need => `${need}-${profile}`),
    }))
    ->Result.seq
  })
  ->Task.resolve
}
