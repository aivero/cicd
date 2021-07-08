import * as path from "path";
import GitMode from "./git.ts";
import ManualMode from "./manual.ts";
import { Mode } from "~/modes/mode.ts";
import { Job } from "~/jobs/job.ts";
import * as E from "fun/either.ts";
import * as TE from "fun/task_either.ts";

enum CicdMode {
  Git = "git",
  Manual = "manual",
}

export type Mode = {
  findJobs: () => E.Either<Error, readonly Job[]>;
}
  /*
  static async run<T extends typeof Mode>() {
    const mode = (new this()) as InstanceType<T>;
    if (mode.findInstances) {
    }
  }
  */
  /*
  dispatchInstances(ints: Instance[]) {
    log.info("Dispatch instances");

    for (const int of ints) {
      for (const [_, clientPayload] of Object.entries(payloads)) {
        //const event: Event = {
        //  owner,
        //  repo,
        //  event_type,
        //  client_payload,
        //};
        log.info(`${Deno.inspect(clientPayload)}`);
        //await octokit.repos.createDispatchEvent(event);
        //const status = {
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

export const modeRunner = (): TE.TaskEither<Error, void> => {
  const kind: CicdMode = Deno.env.get("mode") as CicdMode;

  const mode: Mode = kind === CicdMode.Git
    ? GitMode
    : kind === CicdMode.Manual
      ? ManualMode
      : GitMode

  const jobs = mode.findJobs();

  return TE.right(undefined)
};
