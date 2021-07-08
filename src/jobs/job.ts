import * as path from "path";
import * as fs from "fs";
import * as E from "fun/either.ts";
import { getCommandJobs } from "./command.ts"
import { getConanDockerJobs } from "./docker.ts"
import { getConanJobs } from "./conan.ts"
import { Config } from "../config.ts";


export enum JobMode {
  Conan = "conan",
  Docker = "docker",
  Command = "command",
  ConanInstallTarball = "conan-install-tarball",
  ConanInstallScript = "conan-install-script",
}

export type Job = {
  //name: string;
  //version: string;
  image: string;
  //tags: string[];
  script: readonly string[];

  //mode: JobMode;
}

export const getJobMode = (conf: Config): JobMode => {
  return conf.job
    ? conf.job
    : fs.existsSync(path.join(conf.folder as string, "conanfile.py"))
      ? JobMode.Conan
      : fs.existsSync(path.join(conf.folder as string, "Dockerfile"))
        ? JobMode.Docker
        : JobMode.Command
};

export const loadJobs = (conf: Config): E.Either<Error, readonly Job[]> => {
  const kind = getJobMode(conf);

  return kind === JobMode.Command
    ? getCommandJobs(conf)
    : kind === JobMode.Conan
      ? getConanJobs(conf)
      : kind === JobMode.Docker
        ? getConanDockerJobs(conf)
        : JobMode.ConanInstallTarball
          ? getConanDockerJobs(conf)
          : kind === JobMode.ConanInstallScript
            ? getConanDockerJobs(conf)
            : E.left(Error("Unsupported job"));
};