
type decoder // = { decode: (Js.TypedArray2.Uint8Array.t) => string }

@new external newDecoder: () => decoder = "TextDecoder"
@send external decode: (decoder, Js.TypedArray2.Uint8Array.t) => string = "decode"


//@module("wrap") external run: array<string> => Js.Promise.t<result<string>> = "run"

type runOptions = {
	cmd: array<string>,
	stdout: string,
	stderr: string
}

type processStatus = {
	success: bool
}


type process // = {
	//status: () => Promise.t<processStatus>,
	//output: () => Promise.t<Js.TypedArray2.Uint8Array.t>,
	//stderrOutput: () => Promise.t<Js.TypedArray2.Uint8Array.t>
//}
@send external status: (process) => Promise.t<processStatus> = "status"
@send external output: (process) => Promise.t<Js.TypedArray2.Uint8Array.t> = "output"
@send external stderrOutput: (process) => Promise.t<Js.TypedArray2.Uint8Array.t> = "stderrOutput"



@val external _run: runOptions => process = "Deno.run"

let run = (cmd) => {
  let p = _run({ cmd, stdout: "piped", stderr: "piped" });
  p->status->Task.then((({ success }) => 
	   (success ? p->output : p->stderrOutput)->Task.thenResolve(output => { 
			 let decoded = newDecoder()->decode(output) 
			 success ? Ok(decoded) : Error(decoded)
		})
	));
  //return success
  //  ? Promise.resolve(Ok(decoder.decode(await p.output())))
  //  : Promise.resolve(Error(decoder.decode(await p.stderrOutput())));
};

