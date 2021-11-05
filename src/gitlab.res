let generate = (jobs: array<Job_t.t>) => {
  let encode = Encoder.new()->Encoder.encode
  let jobs = jobs->Array.length > 0 ? jobs : [{name: "empty", needs: [], script: None, image: None}]

  let _ =
    jobs
    ->Array.map(job => {
      [
        `${job.name}:`,
        `  needs: [${job.needs->Array.joinWith(", ", a => a)}]`,
        "  script:",
      ]->Array.concat(
        switch job.image {
        | Some(image) => [`  image: ${image}`]
        | None => []
        },
      )->Array.concat(
        switch job.script {
        | Some(script) => [script->Array.map(l => `    - ${l}`)->Array.joinWith("\n", a => a)]
        | None => []
        },
      )
    })
    ->Array.concatMany
    ->Array.joinWith("\n", a => a)
    ->encode
    ->File.write("generated-config.yml")
}
