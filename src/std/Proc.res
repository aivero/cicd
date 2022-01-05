type runOptions = {
  cmd: array<string>,
  stdout: string,
  stderr: string,
}

type processStatus = {success: bool, code: int}

type process
@send external status: process => Task.t<processStatus> = "status"
@send external output: process => Task.t<Js.TypedArray2.Uint8Array.t> = "output"
@send external stderrOutput: process => Task.t<Js.TypedArray2.Uint8Array.t> = "stderrOutput"

@val external _run: runOptions => process = "Deno.run"

let run = cmd => {
  `Running command: ${cmd->Array.joinWith(" ", a => a)}`->Js.Console.log
  let p = _run({cmd: cmd, stdout: "piped", stderr: "piped"})
  p
  ->status
  ->Task.flatMap(({code}) => {
		let output = p->output
		let stderrOutput = p->stderrOutput
    (code == 0 ? output : stderrOutput)->Task.map(output => {
      let decoded = Decoder.new()->Decoder.decode(output)
      code == 0 ? Ok(decoded) : Error(`${decoded} (Exit code: ${code-> Int.toString})`)
    })
  })
}

@val external exit: int => unit = "Deno.exit"
