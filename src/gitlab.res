let generate = (jobs: array<Job_t.t>) => {
  let encode = Encoder.new()->Encoder.encode
  let jobs = jobs->Array.length > 0 ? jobs : [{name: "empty", needs: [], script: [], image: None}]

  let _ =
    jobs
    ->Array.map(job => {
      [
        `${job.name}:`,
        `  needs: [${job.needs->Array.joinWith(", ", a => a)}]`,
        "  script:",
        job.script->Array.map(l => `    - ${l}`)->Array.joinWith("\n", a => a),
      ]->Array.concat(
        switch job.image {
        | Some(image) => [`  image: ${image}`]
        | None => []
        },
      )
    })
    ->Array.concatMany
    ->Array.joinWith("\n", a => a)
    ->encode
    ->File.write("generated-config.yml")
}
