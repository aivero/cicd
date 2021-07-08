import * as yaml from "std/encoding/yaml.ts";
import log from "./log.ts"
import * as fs from "fs"
import * as TE from 'fun/task_either.ts';
import * as T from 'fun/either.ts';
import * as E from 'fun/either.ts';
import * as IOE from 'fun/io_either.ts';
import * as F from 'fun/fns.ts';
import { parseYaml } from './yaml.ts'
/*
// eslint-disable-next-line functional/no-return-void
export function run<A>(eff: TaskEither<Error, A>): void {
  eff()
    .then(
      fold(
        (e) => {
          // eslint-disable-next-line functional/no-throw-statement
          throw e
        },
        () => {
          process.exitCode = 0
        }
      )
    )
    .catch((e) => {
      console.error(e) // tslint:disable-line no-console

      process.exitCode = 1
    })
}
*/

export const exec = (cmd: string[]): TE.TaskEither<Error, string> => async () => {
  const p = await Deno.run({ 
    cmd, 
    stdout: "piped",
    stderr: "piped",
  });
  const { success } = await p.status();
  const decoder = new TextDecoder();
  return success ? E.right(decoder.decode(await p.output())) : E.left(Error(decoder.decode(await p.stderrOutput())))
}

export const getFileContents = (path: string) => E.tryCatch(() => Deno.readTextFileSync(path) , F.flow(String, Error));
//export const getFileContents = (path: string) => TE.tryCatch((): Promise<string> => test(path) , F.flow(String, Error));
/*export const getFileContents = async (path: string) =>
  await F.flow(TE.tryCatch(() => test(path), F.flow(String, Error)));*/

const parseStringifiedData = <T>(data: string) =>
  TE.tryCatch(() => yaml.parse(data) as T, F.flow(String, Error));

export const getFileData = F.flow(
  getFileContents,
  E.chain(
     parseYaml
  )
);

/*
export const readFile = (path: string): ioEither.IOEither<Error, string> => {
  return ioEither.tryCatch(
    () => fs.readFileSync(path, "utf8"),
    (reason) => new Error(String(reason))
  );
}
*/
/*
export const exec = (cmd: string, env = process.env): TaskEither<Error, NodeJS.ProcessEnv> => {
  log(`Running command: '${cmd}'`);

  // eslint-disable-next-line functional/no-expression-statement
  child_process.exec(cmd, (err) => {
    if (err !== null) {
      return Promise.resolve(left(err))
    }

    return Promise.resolve(right(undefined))
  })

  const cmdList = cmd.split(" ");
  const cmd = args;
  if (!cmd) {
    throw new Error(`Invalid command: '${cmd}'`);
  }
  const child = spawn(cmd, args, {
    stdio: ["ignore", "pipe", "pipe"],
    env: env,
    cwd: env["CWD"],
  });

  let error = ""
  child.stderr.on("data", (data) => {
    error = data.toString("utf8").trim();
  });

  for await (const chunk of child.stdout) {
    core.info(chunk.toString("utf8").trim());
  }

  const exitCode = await new Promise((resolve, reject) => {
    child.on("close", resolve);
  });

  if (exitCode) {
    throw new Error(`Command '${cmd}' failed with code: ${exitCode}\nError Output:\n${error}`);
  }
}
*/

export const parse = <T>(content: string): T => yaml.parse(content) as T;
