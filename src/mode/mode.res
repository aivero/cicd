//type cicdMode = Git | Manual

/*
type Mode = {
  findJobs: () => E.Either<Error, readonly Job[]>;
}
*/
/*
  static async run<T extends typeof Mode>() {
    let mode = (new this()) as InstanceType<T>;
    if (mode.findInstances) {
    }
  }
 */
/*
  dispatchInstances(ints: Instance[]) {
    log.info("Dispatch instances");

    for (let int of ints) {
      for (let [_, clientPayload] of Object.entries(payloads)) {
        //let event: Event = {
        //  owner,
        //  repo,
        //  event_type,
        //  client_payload,
        //};
        log.info(`${Deno.inspect(clientPayload)}`);
        //await octokit.repos.createDispatchEvent(event);
        //let status = {
        //  owner,
        //  repo,
        //  sha: client_payload.commit,
        //  state: "pending" as const,
        //  context: client_payload.context,
        //};
        //await octokit.repos.createCommitStatus(status);
      }
    }
  }
 */

let load = () => {
  let kind = Env.get("mode")

  let ints = switch kind {
  | Some("git") => Git.findInts()
  | _ => Manual.findInts()
  }

  ints->Task.map(ints => {
    ints->Result.flatMap(ints => {
      let zips = ints->Instance.zip
      zips->Job.load
    })
  })->Flat.task
}
