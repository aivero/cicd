
/*
// eslint-disable-next-line functional/no-return-void
function run<A>(eff: TaskEither<Error, A>): void {
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

/*
let exec = (cmd) => async () => {
  let p = await Deno.run({ 
    cmd, 
    stdout: "piped",
    stderr: "piped",
  });
  let { success } = await p.status();
  let decoder = new TextDecoder();
  return success ? Result.Ok(decoder.decode(await p.output())) : Result.Error(decoder.decode(await p.stderrOutput()))
}
*/

//let getFileContents = (path: string) => E.tryCatch(() => Deno.readTextFileSync(path) , F.flow(String, Error));
//let getFileContents = (path: string) => TE.tryCatch((): Promise<string> => test(path) , F.flow(String, Error));
/*let getFileContents = async (path: string) =>
  await F.flow(TE.tryCatch(() => test(path), F.flow(String, Error)));*/

/*
let parseStringifiedData = (data) =>
  TE.tryCatch(() => yaml.parse(data), F.flow(String, Error));
*/

/*
let getFileData = F.flow(
  getFileContents,
  E.chain(
     parseYaml
  )
);
*/

/*
let readFile = (path: string): ioEither.IOEither<Error, string> => {
  return ioEither.tryCatch(
    () => fs.readFileSync(path, "utf8"),
    (reason) => new Error(String(reason))
  );
}
*/
/*
let exec = (cmd: string, env = process.env): TaskEither<Error, NodeJS.ProcessEnv> => {
  log(`Running command: '${cmd}'`);

  // eslint-disable-next-line functional/no-expression-statement
  child_process.exec(cmd, (err) => {
    if (err !== null) {
      return Promise.resolvResult.Error(err))
    }

    return Promise.resolvResult.Ok(undefined))
  })

  let cmdList = cmd.split(" ");
  let cmd = args;
  if (!cmd) {
    throw new Error(`Invalid command: '${cmd}'`);
  }
  let child = spawn(cmd, args, {
    stdio: ["ignore", "pipe", "pipe"],
    env: env,
    cwd: env["CWD"],
  });

  let error = ""
  child.stderr.on("data", (data) => {
    error = data.toString("utf8").trim();
  });

  for await (let chunk of child.stdout) {
    core.info(chunk.toString("utf8").trim());
  }

  let exitCode = await new Promise((resolve, reject) => {
    child.on("close", resolve);
  });

  if (exitCode) {
    throw new Error(`Command '${cmd}' failed with code: ${exitCode}\nError Output:\n${error}`);
  }
}
*/

/*
let parse = (content) => yaml.parse(content);
*/