import * as E from "fun/either.ts";
import * as F from "fun/fns.ts";
import * as A from "fun/array.ts";
import * as R from "fun/record.ts";
import * as U from "~/util.ts";
import * as path from "path";
import * as fs from "fs";
import { Mode } from "~/modes/mode.ts";
import { Job } from "~/jobs/job.ts";
import { getDockerImage } from "../detect.ts"
import { Config, ConfigProfile } from "../config.ts";


const getConanCmdPost = (): string[] => {
  return [`conan remove --locks`, `conan remove * -f`];
};

const getConanArgs = (conf: Config): string[] => {
  // Settings
  const args = Deno.env.get("args")?.split(" ") || [];
  const set = F.pipe(
    conf.options || {},
    Object.entries,
    A.map(([key, val]) => [key, val == "true" ? "True" : val == "false" ? "False" : val]),
    A.map(([key, val]) => `-s ${conf.name}:${key}=${val}`)
  )
  const opt = F.pipe(
    conf.options || {},
    Object.entries,
    A.map(([key, val]) => [key, val == "true" ? "True" : val == "false" ? "False" : val]),
    A.map(([key, val]) => `-o ${conf.name}:${key}=${val}`)
  )
};

export const getConanJob = (conf: ConfigProfile): E.Either<Error, Job> => {
  return {
    image: getDockerImage()
  }
}

export const getConanCmds = (conf: string): string[] => {
  return [
    `conan config install $CONAN_CONFIG_URL -sf $CONAN_CONFIG_DIR`,
    `conan user $CONAN_LOGIN_USERNAME -p $CONAN_LOGIN_PASSWORD -r $CONAN_REPO_ALL`,
    `conan user $CONAN_LOGIN_USERNAME -p $CONAN_LOGIN_PASSWORD -r $CONAN_REPO_INTERNAL`,
    `conan user $CONAN_LOGIN_USERNAME -p $CONAN_LOGIN_PASSWORD -r $CONAN_REPO_PUBLIC`,
    `conan config set general.default_profile=${conf.profile}`,
  ];
}

const validateConfig = (conf: Config): E.Either<Error,Config> => !conf.profiles ? E.left(Error("No profiles")) : E.right(conf)

const zipConfig = (conf: Config): ConfigProfile[] => conf.profiles?.map((profile: string) => ({ conf, profile})) || []

export const getConanJobs = (
  conf: Config,
): E.Either<Error, Job[]> => {
  const bla = F.pipe(
    conf,
    validateConfig,
    E.map(
      F.flow(
        //A.of,
        zipConfig,
        A.map(getConanJob),
        //([conf])(conf.profiles as string[]),
        //(conf: Config) => A.zip([conf])(conf.profiles as string[]),
        //A.map(getConanJob)
        //E.right,
      )
    )
    //(E.map(A.map (conf: Config) => !conf.profiles ? E.left(Error("No profiles")) : E.right(conf)),
    //chain(
  )


  // Check if package is proprietary
  const conanRepo = getConanRepo(conf);
  const args = getConanArgs(conf)

  const cmds = getConanCmds(profile);


  const image = getDockerImage(conf, profile);
  if (E.isLeft(image)) {
    return E.left(image.left);
  }

  return E.right([{
      script: cmds,
      image: image.right,
  } as Job]);
}

const getConanRepo = (conf: Config): E.Either<Error, string> => {
  return F.pipe(
    U.getFileContents(path.join(conf.folder as string, "conanfile.py")),
    E.map((conanfile: string) => conanfile.includes("Proprietary")
      ? "$CONAN_REPO_PUBLIC"
      : "$CONAN_REPO_INTERNAL"
    )
  )
};
