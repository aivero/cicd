import * as E from "fun/either.ts";
import * as A from "fun/array.ts";
import * as F from "fun/fns.ts";
import { Job } from "~/jobs/job.ts";
import { Config } from "~/config.ts";
import { getDockerImage } from "~/detect.ts"

const traverseOption = A.IndexedTraversable.traverse(E.Applicative);
const seq = traverseOption((a: E.Either<Error, string>) => a);


export const getCommandJobs = (conf: Config): E.Either<Error, readonly Job[]> => {
  return F.pipe(
    conf,
    (conf: Config) => conf.profiles || [],
    A.map(getDockerImage(conf)),
    seq,
    E.map(A.map((image: string): Job => ({ script: conf.cmds || [], image  })))
  )
};
