// Generated by ReScript, PLEASE EDIT WITH CARE

import * as Task from "./Task.js";
import * as Belt_Array from "../../../../node_modules/rescript/lib/es6/belt_Array.js";

function array(a) {
  return a.reduce((function (a, e) {
                if (a.TAG === /* Ok */0) {
                  if (e.TAG === /* Ok */0) {
                    return {
                            TAG: /* Ok */0,
                            _0: Belt_Array.concat([e._0], a._0)
                          };
                  } else {
                    return {
                            TAG: /* Error */1,
                            _0: e._0
                          };
                  }
                } else {
                  return {
                          TAG: /* Error */1,
                          _0: a._0
                        };
                }
              }), {
              TAG: /* Ok */0,
              _0: []
            });
}

function task(to) {
  return Task.flatMap(to, (function (r) {
                if (r.TAG === /* Ok */0) {
                  return r._0;
                } else {
                  return Task.resolve({
                              TAG: /* Error */1,
                              _0: r._0
                            });
                }
              }));
}

export {
  array ,
  task ,
  
}
/* No side effect */