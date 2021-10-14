const run = async (cmd) => {
  const p = Deno.run({ cmd, stdout: "piped", stderr: "piped" });
  const { success } = await p.status();
  const decoder = new TextDecoder();
  return success
    ? Promise.resolve(Ok(decoder.decode(await p.output())))
    : Promise.resolve(Error(decoder.decode(await p.stderrOutput())));
};

export { run };