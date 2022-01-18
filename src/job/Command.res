open Instance
open Job_t

let getJobs = (zips: array<Instance.zip>) => {
  zips
  ->Js.Array2.filter(zip => zip.mode == #command)
  ->Array.map(zip => {
    zip
    ->Detect.getImage
    ->Result.flatMap(image =>
      switch (zip.int.name, zip.int.cmds) {
      | (Some(name), Some(cmds)) => Ok({
          name: `${name}-${zip.profile}`,
          script: Some(cmds),
          image: Some(image),
          tags: None,
          variables: None,
          extends: None,
          needs: switch zip.int.req {
          | Some(needs) => needs->Array.map(need => `${need}-${zip.profile}`)
          | None => []
          },
        })
      | _ => Error(`${zip.int.name->Option.getExn}: name or cmds not specified`)
      }
    )
  })->Seq.result
  ->Task.resolve
}
