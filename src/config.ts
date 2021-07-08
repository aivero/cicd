import * as path from "path";
import * as fs from "fs";
import * as O from 'fun/option.ts'
import * as E from 'fun/either.ts'
import * as F from 'fun/fns.ts'
import * as A from 'fun/array.ts'
import { getFileContents } from "./util.ts";
import { pipe } from "fun/fns.ts";
import { parseYaml, Yaml } from "./yaml.ts";
import { JobMode } from "./jobs/job.ts";

export const CONFIG_NAME = "devops.yml";

export type Config = {
  name?: string;
  version?: string;
  commit?: string;
  branch?: string;
  folder?: string;
  cmdsPre?: readonly string[];
  cmds?: readonly string[];
  cmdsPost?: readonly string[];
  image?: string;
  tags?: readonly string[];
  job?: JobMode;
  // Conan
  profiles?: readonly string[];
  settings?: Record<string, string>;
  options?: Record<string, string>;
  bootstrap?: boolean;
  debugPkg?: boolean;
  // Docker
  conanInstall?: readonly string[];
  subdir?: string;
  script?: readonly string[];
  tag?: string;
  platform?: string;
  dockerfile?: string;
}

type Concrete<T> = {
  [P in keyof T]-?: T[P];
};

type Options<T> = {
  [P in keyof T]: O.Option<T[P]>;
};

type OptConfig = Options<Concrete<Config>>;

export type ConfigProfile = { conf: Config, profile: string };


export const findConfig = (dir: string): O.Option<string> => {
  const confPath = path.join(dir, CONFIG_NAME);
  return fs.existsSync(confPath)
    ? O.some(confPath)
    : dir != "."
      ? findConfig(path.dirname(dir))
      : O.none
}



export const loadConfigFile = (confPath: string): E.Either<Error, readonly Config[]> => pipe(
  confPath,
  getFileContents,
  E.chain(loadConfig(confPath)),
)

export const loadConfig = (confPath: string) => (content: string): E.Either<Error, readonly Config[]> => pipe(
  content,
  parseYaml,
  E.map(
    F.flow(
      // TODO: do some yaml validation
      (yaml: Yaml) => (yaml as readonly Config[]),
      A.map(createConfig(confPath))
    )
  )
)

const createConfig = (folderPath: string) => (config: Config): Config => ({
      ...config,
      name: config.name ?? path.basename(folderPath),
      commit: config.commit ?? Deno.env.get("CI_COMMIT_SHA"),
      version: config.version ?? Deno.env.get("CI_COMMIT_SHA"),
      branch: config.branch ?? Deno.env.get("CI_COMMIT_REF_NAME"),
      profiles: config.profiles ?? ["linux-x86_64", "linux-armv8"],
      folder: config.folder ? path.join(folderPath, config.folder) : folderPath,
})

const createConfigOpt = (folderPath: string) => (config: Config): E.Either<Error, OptConfig> => ({
      ...config,
      name: config.name ?? path.basename(folderPath),
      commit: config.commit ?? Deno.env.get("CI_COMMIT_SHA"),
      version: config.version ?? Deno.env.get("CI_COMMIT_SHA"),
      branch: config.branch ?? Deno.env.get("CI_COMMIT_REF_NAME"),
      profiles: config.profiles ?? ["linux-x86_64", "linux-armv8"],
      folder: config.folder ? path.join(folderPath, config.folder) : folderPath,
})

/*
const loadConfig = (confPath: string, confRaw: string): Config[] => {
  const conf: Config[] = yaml.parse(confRaw) as Config[] || [];
  const folderPath = path.dirname(confPath);
  return conf.map((int: Config) => ({
      ...int,
      name: int.name ?? path.basename(folderPath),
      commit: int.commit ?? Deno.get("CI_COMMIT_SHA"),
      version: int.version ?? Deno.get("CI_COMMIT_SHA"),
      branch: int.branch ?? Deno.get("CI_COMMIT_REF_NAME"),
      profiles: int.profiles ?? ["linux-x86_64", "linux-armv8"],
      folder: int.folder ? path.join(folderPath, int.folder) : folderPath,
  }));

  //int.image = conf.image ?? getImage(profile);
  //int.tags = conf.tags ?? getTags(profile);
};
*/


