let rec chunk = (array, size) => {
  let cur = array->Array.slice(~offset=0, ~len=size)
  let rest = array->Array.slice(~offset=size, ~len=array->Array.length - size)
  switch rest->Array.length {
  | 0 => [cur]
  | _ => [cur]->Array.concat(rest->chunk(size))
  }
}

let generateJob = (job: Job_t.t) => {
  Array.concatMany([
    [`${job.name}:`, `  needs: [${job.needs->Array.joinWith(", ", a => a)}]`],
    switch job.image {
    | Some(image) => [`  image: ${image}`]
    | None => []
    },
    switch job.script {
    | Some(script) => ["  script:"]->Array.concat(script->Array.map(l => `    - ${l}`))
    | None => []
    },
  ])
}

let generate = (jobs: array<Job_t.t>) => {
  let encode = Encoder.new()->Encoder.encode
  let jobs =
    jobs->Array.length > 0
      ? jobs
      : [{name: "empty", needs: [], script: Some(["echo"]), image: None}]

  jobs
  ->Array.map(generateJob)
  ->Array.concatMany
  ->Array.joinWith("\n", a => a)
  ->encode
  ->File.write("generated-config.yml")
}
