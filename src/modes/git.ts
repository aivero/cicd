import * as log from "log";
import * as fs from "fs";
import * as path from "path";
import * as E from "fun/either.ts"
import * as A from "fun/array.ts"
import * as O from "fun/option.ts"
import * as F from "fun/fns.ts"
import * as U from "~/util.ts"
import * as TE from "fun/task_either.ts"
import hash from "hash";
import { Mode } from "~/modes/mode.ts";
import { Job } from "~/jobs/job.ts";
import { Config, CONFIG_NAME, findConfig, loadConfig, loadConfigFile } from "~/config.ts";

const traverseOption = A.IndexedTraversable.traverse(E.Applicative);
const seqConf = traverseOption((a: E.Either<Error, readonly Config[]>) => a);

const seq = A.createSequence(E.Applicative);

const lastRev = Deno.env.get("CI_COMMIT_BEFORE_SHA") || "HEAD^";

const findJobs = (): TE.TaskEither<Error, Job[]> => {
  //log.info("Git Mode: Create instances from changed files in git");
  //const ints: Job[] = [];
  //const intsHash = new Set<string>();
  // Compare to previous commit
  const bla = F.pipe(
    U.exec(["git", "diff", "--name-only", lastRev, "HEAD"]),
    TE.chain( // chain
      (filePath: string) =>
      F.pipe(
        filePath,
        (output: string) => output.trim().split("\n"),
        // Only handle files that exist in current commit
        A.filter(fs.existsSync),
        A.map(
          F.flow(
            path.dirname,
            findConfig,
          ),
        ),
        A.reduce((confs: string[], conf: O.Option<string>) => O.isSome(conf) ? confs.concat(conf.value) : confs, []),
        A.map(
          F.flow(
            E.of,
            E.chain((confPath: string) => path.basename(filePath) == CONFIG_NAME ? handleConfigChange(filePath) : handleFileChange(confPath, filePath))
          )
        ),
        seq,
        E.map(A.join),
        TE.fromEither
      )
    )
  )
  /*
  for (const d of files) {
    let filePath = d.file;


    const file = path.basename(filePath);
    const fileDir = path.dirname(filePath);
    const confPath = findConfig(fileDir);
    if (!confPath) {
      log.info(`Couldn't find ${CONFIG_NAME} for filePath: ${file}`);
      continue;
    }

    let jobsNew: Job[];
    if (file == CONFIG_NAME) {
      jobsNew = await handleConfigChange(filePath);
    } else {
      jobsNew = await handleFileChange(confPath, filePath);
    }
    for (const job of jobsNew) {
      const jobHash = hash(job);
      if (!intsHash.has(jobHash)) {
        intsHash.add(jobHash);
        ints.push(job);
      }
    }
  }
  return ints;*/
}

const handleNewConfig = () => {
  //log.info(`Created: ${confPath}`);
  for (const int of confNew) {
    const intHash = hash(int);
    const { name, version } = int;
    //log.info(
    //  `Config name/version (hash): ${name}/${version} (${intHash})`,
    //);
  }
  return confNew;
}

const handleOldConfig = (confPath) => {
    // Compare to old config.yml
  //log.info(`Changed: ${confPath}`);
  //const jobs: Job[] = [];
  U.exec(["git", "show", `${lastRev}:${confPath}`])
  const confOld = loadConfig(
    confPath,
  );
  const hashsOld = [...confOld].map((int) => hash(int));
  for (const intNew of confNew) {
    // Check if instance existed in old commit or if instance data changed
    if (!hashsOld.includes(hash(intNew))) {
      //const intHash = hash(intNew);
      //const { name, version } = intNew;
      //log.info(
      //  `Config name/version (hash): ${name}/${version} (${intHash})`,
      //);
      //jobs.push(intNew);
    }
  }
}

const handleConfigChange = (confPath: string): E.Either<Error, readonly Config[]> => {
  // New config.yml
  const bla = F.pipe(
    U.exec(["git", "show", `HEAD:${confPath}`]),
    TE.chain(
      F.flow(
        loadConfig(confPath),
        TE.fromEither
      )
    )
  )
  U.exec(["git", "ls-tree", "-r", lastRev]);
  //const filesOld = U.exec(["git", "ls-tree", "-r", lastRev]);
  //if (!filesOld.includes(confPath)) {
}

const handleFileChange = (
  confPath: string,
  filePath: string,
): E.Either<Error, readonly Config[]> => {
  return F.pipe(
    loadConfigFile(confPath),
    E.map(
      F.flow(
        A.filter(({ folder }) => path.join(folder || "").endsWith(path.dirname(filePath)))
      )
    )
  )
  /*
  for (const job of conf) {
    const { name, version, folder } = job;
    if (path.join(folder).endsWith(path.dirname(filePath))) {
      const intHash = hash(job);
      log.info(
        `Config name/version (hash): ${name}/${version} (${intHash})`,
      );
      jobs.push(job);
    }
  }
  return jobs;
  */
}

export default (): Mode => ({
  findJobs
})