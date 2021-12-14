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
  let chunkSize = 100
  let jobs =
    jobs->Array.length > 0
      ? jobs
      : [{name: "empty", needs: [], script: Some(["echo"]), image: None}]

  let chunks =
    jobs
    ->chunk(chunkSize)
    ->Array.map(chunk => {
      chunk->Array.map(generateJob)
    })

  let includeLines = chunks->Array.mapWithIndex((i, chunk) => {
    let name = `generated-config-${(i * chunkSize)->Int.toString}.yml`
    chunk->Array.concatMany->Array.joinWith("\n", a => a)->encode->File.write(name)
    `- '${name}'`
  })

  ["include:"]
  ->Array.concat(includeLines)
  ->Array.joinWith("\n", a => a)
  ->encode
  ->File.write("generated-config.yml")
}
