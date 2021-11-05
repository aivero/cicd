open Instance

let getJobs = (zips: array<Instance.zip>) => {
  zips
  ->Js.Array2.filter(zip => zip.mode == #command)
  ->Array.map(zip => {
    switch (zip.int.name, zip.int.cmds, zip->Detect.getImage) {
    | (Some(name), Some(cmds), Ok(image)) =>
      (
        {
          Ok({
            name: `${name}-${zip.profile}`,
            script: cmds,
            image: Some(image),
            needs: switch zip.int.req {
            | Some(needs) => needs->Array.map(need => `${need}-${zip.profile}`)
            | None => []
            },
          })
        }: result<Job_t.t, string>
      )
    | (_, _, Error(err)) => Error(err)
    | (_, _, _) => Error(`${zip.int.name->Option.getExn}: name or cmds not specified`)
    }
  })
  ->Flat.array
  ->Task.resolve
}
