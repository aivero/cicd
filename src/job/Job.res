open Jobt

type mode = [
  | #conan
  | #docker
  | #command
]

let parseMode = str => {
  switch str {
  | "conan" => #conan
  | "docker" => #docker
  | _ => #command
  }
}

let hashLength = 4
let hashN = Hash.hashN(_, hashLength)

let handleDuplicates = jobs => {
  jobs
  ->Array.groupBy(((key, _)) => key)
  ->Array.flatMap(((key, group)) => {
    switch group {
    | [job] => [job]
    | jobs => {
        let jobs = jobs->Array.map(((key, job)) => (`${key}@${job->hashN}`, job))
        jobs->Array.concat([
          (
            key,
            {
              ...Jobt.default,
              script: Some(["echo"]),
              tags: Some(["x86_64", "saas-linux-large-amd64"]),
              extends: Some([".git-strat-none"]),
              needs: Some(jobs->Array.map(((key, _)) => key)->Array.uniq),
            },
          ),
        ])
      }
    }
  })
}

let load = ints => {
  Async.seq(
    [Command.getJobs, Conan.getJobs, Docker.getJobs]->Array.map(f => ints->f),
  )->Async.map(jobs => jobs->Result.seq->Result.map(jobs => jobs->Array.flat->handleDuplicates))
}
