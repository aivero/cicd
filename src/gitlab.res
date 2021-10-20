let generate = (jobs: array<Job_t.t>) => {
  let encode = Encoder.new()->Encoder.encode
  let _ =
    jobs
    ->Array.map(job => [
      `${job.name}:`,
      `  image: ${job.image}`,
      `  needs: [${job.needs->Array.joinWith(", ", a => a)}]`,
      "  script:",
      job.script->Array.map(l => `    - ${l}`)->Array.joinWith("\n", a => a),
    ])
    ->Array.concatMany
    ->Array.joinWith("\n", a => a)
    ->encode
    ->File.write("generated-config.yml")
}
