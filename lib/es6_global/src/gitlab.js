// Generated by ReScript, PLEASE EDIT WITH CARE

import * as $$File from "./std/file.js";
import * as Curry from "../../../node_modules/rescript/lib/es6/curry.js";
import * as Belt_Array from "../../../node_modules/rescript/lib/es6/belt_Array.js";

function generate(jobs) {
  var partial_arg = new TextEncoder();
  var encode = function (param) {
    return partial_arg.encode(param);
  };
  $$File.write(Curry._1(encode, Belt_Array.joinWith(Belt_Array.concatMany(Belt_Array.map(jobs, (function (job) {
                          return [
                                  job.name + ":",
                                  "  image: " + job.image,
                                  "  needs: [" + Belt_Array.joinWith(job.needs, ", ", (function (a) {
                                          return a;
                                        })) + "]",
                                  "  script:",
                                  Belt_Array.joinWith(Belt_Array.map(job.script, (function (l) {
                                              return "    - " + l;
                                            })), "\n", (function (a) {
                                          return a;
                                        }))
                                ];
                        }))), "\n", (function (a) {
                  return a;
                }))), "generated-config.yml");
  
}

export {
  generate ,
  
}
/* File Not a pure module */