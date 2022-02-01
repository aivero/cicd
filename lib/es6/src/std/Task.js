// Generated by ReScript, PLEASE EDIT WITH CARE

import * as Int from "./Int.js";
import * as $$Array from "./Array.js";
import * as Async from "./Async.js";
import * as Curry from "rescript/lib/es6/curry.js";
import * as Result from "./Result.js";
import * as Console from "./Console.js";

function to(t) {
  return Async.to({
              TAG: /* Ok */0,
              _0: t
            });
}

function toError(t) {
  return Async.to({
              TAG: /* Error */1,
              _0: t
            });
}

var fromResult = Async.to;

function flatten(to) {
  return Async.flatMap(to, (function (r) {
                if (r.TAG === /* Ok */0) {
                  return r._0;
                } else {
                  return Async.to({
                              TAG: /* Error */1,
                              _0: r._0
                            });
                }
              }));
}

function map(a, fn) {
  return Async.map(a, (function (res) {
                return Result.map(res, fn);
              }));
}

function flatMap(a, fn) {
  return flatten(Async.map(a, (function (res) {
                    return Result.map(res, fn);
                  })));
}

function mapError(a, fn) {
  return Async.map(a, (function (res) {
                return Result.mapError(res, fn);
              }));
}

function flatMapError(a, fn) {
  return flatten(Async.map(a, (function (res) {
                    return Result.mapError(res, fn);
                  })));
}

function fold(a, fn) {
  return Async.map(a, (function (res) {
                return Result.fold(res, fn);
              }));
}

function flatFold(a, fn) {
  return flatten(Async.map(a, (function (res) {
                    return Result.fold(res, fn);
                  })));
}

function seq(a) {
  return Async.map(Promise.all(a), Result.seq);
}

function seq2(param) {
  return Async.map(Promise.all([
                  param[0],
                  param[1]
                ]), Result.seq2);
}

function seq3(param) {
  return Async.map(Promise.all([
                  param[0],
                  param[1],
                  param[2]
                ]), Result.seq3);
}

function seq4(param) {
  return Async.map(Promise.all([
                  param[0],
                  param[1],
                  param[2],
                  param[3]
                ]), Result.seq4);
}

function pool(tasks, count) {
  var curTasks = Promise.all($$Array.map($$Array.slice(tasks, 0, count), (function (f) {
              return new Promise((function (resolve) {
                            return Curry._1(resolve, Curry._1(f, undefined));
                          }));
            })));
  var rest = $$Array.slice(tasks, count, $$Array.length(tasks) - count | 0);
  Console.log("pool: " + Int.toString($$Array.length(rest)));
  return flatten(Async.flatMap(curTasks, (function (res1) {
                    var tasks = Async.map(Promise.all(res1), Result.seq);
                    return map(tasks, (function (res1) {
                                  var match = $$Array.length(rest);
                                  if (match !== 0) {
                                    return map(pool(rest, count), (function (res2) {
                                                  return $$Array.flatten([
                                                              res1,
                                                              res2
                                                            ]);
                                                }));
                                  } else {
                                    return Async.to({
                                                TAG: /* Ok */0,
                                                _0: res1
                                              });
                                  }
                                }));
                  })));
}

export {
  to ,
  toError ,
  fromResult ,
  flatten ,
  map ,
  flatMap ,
  mapError ,
  flatMapError ,
  fold ,
  flatFold ,
  seq ,
  seq2 ,
  seq3 ,
  seq4 ,
  pool ,
  
}
/* No side effect */