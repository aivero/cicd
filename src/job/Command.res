open Instance
open Job_t

type cmdInstance = {
  base: Instance.t,
  profile: string,
  //extends: array<string>,
}

let getInstances = (int: Instance.t) => {
  let image = Some("") //name->Profile.getImage
  Ok(int.profiles->Array.map(profile => {base: int, profile: profile}))
}

let getJobs = (ints: array<Instance.t>) => {
  ints
  ->Js.Array2.filter(int => int.mode == #command)
  ->Array.map(getInstances)
  ->Seq.result
  ->Result.flatMap(ints => {
    let ints = ints->Flat.array
    ints
    ->Array.map(({base: {name, image, cmds, reqs}, profile}) => Ok({
      name: `${name}-${profile}`,
      script: Some(cmds),
      image: image,
      tags: None,
      variables: None,
      extends: None,
      needs: reqs->Array.map(need => `${need}-${profile}`),
    }))
    ->Seq.result
  })
  ->Task.resolve
}
