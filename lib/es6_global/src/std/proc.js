// Generated by ReScript, PLEASE EDIT WITH CARE

import * as Task from "./task.js";
import * as Belt_Array from "../../../../node_modules/rescript/lib/es6/belt_Array.js";

function run(cmd) {
  console.log("Running command: " + Belt_Array.joinWith(cmd, " ", (function (a) {
              return a;
            })));
  var p = Deno.run({
        cmd: cmd,
        stdout: "piped",
        stderr: "piped"
      });
  return Task.flatMap(p.status(), (function (param) {
                var success = param.success;
                return Task.map(success ? p.output() : p.stderrOutput(), (function (output) {
                              var decoded = new TextDecoder().decode(output);
                              if (success) {
                                return {
                                        TAG: /* Ok */0,
                                        _0: decoded
                                      };
                              } else {
                                return {
                                        TAG: /* Error */1,
                                        _0: decoded
                                      };
                              }
                            }));
              }));
}

export {
  run ,
  
}
/* No side effect */