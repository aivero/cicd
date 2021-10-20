type runOptions = {
	cmd: array<string>,
	stdout: string,
	stderr: string
}

type processStatus = {
	success: bool
}


type process
@send external status: (process) => Task.t<processStatus> = "status"
@send external output: (process) => Task.t<Js.TypedArray2.Uint8Array.t> = "output"
@send external stderrOutput: (process) => Task.t<Js.TypedArray2.Uint8Array.t> = "stderrOutput"

@val external _run: runOptions => process = "Deno.run"

let run = (cmd) => {
	`Running command: ${cmd->Array.joinWith(" ", a => a)}`->Js.Console.log
  let p = _run({ cmd, stdout: "piped", stderr: "piped" });
  p->status->Task.flatMap((({ success }) => 
	   (success ? p->output : p->stderrOutput)->Task.map(output => { 
			 let decoded = Decoder.new()->Decoder.decode(output) 
			 success ? Ok(decoded) : Error(decoded)
		})
	));
};

