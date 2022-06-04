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

let hashLength = 3
let hashN = Hash.hashN(_, hashLength)

let handleDuplicates = jobs => {
  jobs
  ->Array.groupBy(((key, _)) => key)
  ->Array.flatMap(((key, group)) => {
    switch group {
    | [job] => [job]
    | jobs => {
        let jobs = jobs->Array.map(((key, job)) => (`${key}@${job->hashN}`, job))
        let needs = jobs->Array.map(((_, job)) => job.needs)
        let firstNeeds = needs[0]
        let allNeedsAreTheSame = needs
          ->Array.map((needs) => Some(needs) == firstNeeds)
          ->Array.reduce((acc, theSame) => {
            acc && theSame
          }, true)

        let jobs = switch allNeedsAreTheSame {
        | true => {
          let needsKey = `${key}-needs`
          let needsJob = (
            needsKey,
            {
              ...Jobt.default,
              script: Some(["echo"]),
              tags: Some(["x86_64"]),
              needs: firstNeeds->Option.flat,
            },
          )

          jobs
            ->Array.map(((key, job)) => (
              key,
              {
                ...job,
                needs: Some([needsKey])
              }
            ))
            ->Array.concat([needsJob])
        }
        | false => jobs
        }

        jobs->Array.concat([
          (
            key,
            {
              ...Jobt.default,
              script: Some(["echo"]),
              tags: Some(["x86_64"]),
              needs: Some(jobs->Array.map(((key, _)) => key)),
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
