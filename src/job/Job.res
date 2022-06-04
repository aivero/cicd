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
        let subJobs = jobs->Array.map(((key, job)) => (`${key}@${job->hashN}`, job))
        let needs = subJobs->Array.map(((_, job)) => job.needs)
        let firstNeeds = needs[0]->Option.flat
        let allNeedsAreTheSame = needs
          ->Array.map((needs) => needs == firstNeeds)
          ->Array.reduce((acc, theSame) => {
            acc && theSame
          }, true)

        let allThejobs = switch (
          allNeedsAreTheSame,
          firstNeeds
            ->Option.map(Array.length)
        ) {
        | (false, _) => subJobs
        | (true, Some(0)) => subJobs
        | (true, Some(1)) => subJobs
        | (true, Some(2)) => subJobs
        | _ => {
          let needsKey = `${key}-needs`
          let needsJob = (
            needsKey,
            {
              ...Jobt.default,
              script: Some(["echo"]),
              tags: Some(["x86_64"]),
              needs: firstNeeds,
            },
          )

          subJobs
            ->Array.map(((key, job)) => (
              key,
              {
                ...job,
                needs: Some([needsKey])
              }
            ))
            ->Array.concat([needsJob])
        }
        }

        allThejobs->Array.concat([
          (
            key,
            {
              ...Jobt.default,
              script: Some(["echo"]),
              tags: Some(["x86_64"]),
              needs: Some(subJobs->Array.map(((key, _)) => key)),
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
