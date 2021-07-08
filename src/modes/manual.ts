import * as log from "log";
import { Job, loadJobs } from "~/jobs/job.ts";
import { Config, loadConfigFile } from "~/config.ts";

import * as U from "~/util.ts";
import * as E from "fun/either.ts";
import * as A from "fun/array.ts";
import * as F from "fun/fns.ts";
import * as TE from "fun/task_either.ts";

const seq = A.createSequence(E.Applicative);

const filterConfig = (name: string, version: string) => A.filter((c: Config): boolean => (
  (name == "*" || (c.name?.includes(name) || false) &&
  (version == "*" || version == c.version)
)))

const findJobs = (): TE.TaskEither<Error, readonly Job[]> => {
  log.info("Manual Mode: Create instances from manual args");
  const [inputName, inputVersion] = Deno.env.get("component")?.split("/") || ["", ""];

  const bla = F.pipe(
    U.exec([
      "git",
      "ls-files",
      "**/devops.yml",
      "--recurse-submodules",
    ]),
    TE.chain(
      F.flow(
        (output: string) => output.trim().split("\n"),
        A.map(loadConfigFile),
        seq,
        E.map(
          F.flow(
            A.join,
            filterConfig(inputName, inputVersion),
            A.map(loadJobs),
            seq,
            E.map(
              A.join
            )
          )
        ),
        TE.fromEither
      )
    )
  )

  //E.fold(bla, console.log, console.log)

              /*
  for (const confPath of confPaths) {
    for (const int of ints) {
      log.info(
        `Build component/version (hash): ${int.name}/${int.version} (${hash(int)
        })`,
      );
      ints.push(int);
    }
  }
  return jobs;
  */
}

export default {
    findJobs
}