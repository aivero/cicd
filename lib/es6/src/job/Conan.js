// Generated by ReScript, PLEASE EDIT WITH CARE

import * as Env from "../std/Env.js";
import * as Dict from "../std/Dict.js";
import * as $$File from "../std/File.js";
import * as Hash from "../std/Hash.js";
import * as Json from "../std/Json.js";
import * as List from "../std/List.js";
import * as Proc from "../std/Proc.js";
import * as Task from "../std/Task.js";
import * as Yaml from "../std/Yaml.js";
import * as Path from "path";
import * as $$Array from "../std/Array.js";
import * as Tuple from "../std/Tuple.js";
import * as Result from "../std/Result.js";
import * as $$String from "../std/String.js";
import * as Caml_obj from "rescript/lib/es6/caml_obj.js";
import * as Caml_option from "rescript/lib/es6/caml_option.js";

function hashN(__x) {
  return Hash.hashN(__x, 3);
}

function getArgs(name, $$int) {
  var args = Deno.env.get("args");
  var args$1 = (args == null) ? [] : $$String.split(args, " ");
  var sets = Yaml.get($$int, "settings");
  var tmp;
  tmp = typeof sets === "number" || sets.TAG !== /* Object */2 ? Dict.empty(undefined) : Dict.map(sets._0, (function (param) {
            var val = param[1];
            var key = param[0];
            if (typeof val === "number" || !(val.TAG === /* Bool */4 && val._0)) {
              return [
                      key,
                      "False"
                    ];
            } else {
              return [
                      key,
                      "True"
                    ];
            }
          }));
  var sets$1 = $$Array.map(Dict.toArray(tmp), (function (param) {
          return "-s " + name + ":" + param[0] + "=" + param[1];
        }));
  var opts = Yaml.get($$int, "options");
  var tmp$1;
  tmp$1 = typeof opts === "number" || opts.TAG !== /* Object */2 ? Dict.empty(undefined) : Dict.map(opts._0, (function (param) {
            var val = param[1];
            var key = param[0];
            if (typeof val === "number" || !(val.TAG === /* Bool */4 && val._0)) {
              return [
                      key,
                      "False"
                    ];
            } else {
              return [
                      key,
                      "True"
                    ];
            }
          }));
  var opts$1 = $$Array.map(Dict.toArray(tmp$1), (function (param) {
          return "-o " + name + ":" + param[0] + "=" + param[1];
        }));
  return $$Array.flatten([
              args$1,
              sets$1,
              opts$1
            ]);
}

function getRepo(folder) {
  return Result.map($$File.read(Path.join(folder, "conanfile.py")), (function (content) {
                if ($$String.includes(content, "Proprietary")) {
                  return "$CONAN_REPO_INTERNAL";
                } else {
                  return "$CONAN_REPO_PUBLIC";
                }
              }));
}

function getVariables(param) {
  var args = param.args;
  var match = param.base;
  var version = match.version;
  var match$1 = $$String.match(version, /^[0-9a-f]{40}$/);
  return Dict.fromArray($$Array.concat($$Array.concat([
                      [
                        "NAME",
                        match.name
                      ],
                      [
                        "VERSION",
                        version
                      ],
                      [
                        "FOLDER",
                        match.folder
                      ],
                      [
                        "REPO",
                        param.repo
                      ],
                      [
                        "PROFILE",
                        param.profile
                      ]
                    ], $$Array.empty(args) ? [] : [[
                          "ARGS",
                          $$Array.join(args, " ")
                        ]]), match$1 !== undefined ? [[
                      "UPLOAD_ALIAS",
                      "1"
                    ]] : []));
}

function init(ints) {
  var exportPkgs = $$Array.reduce(ints, (function (pkgs, param) {
          var folder = param.folder;
          var version = param.version;
          var name = param.name;
          if ($$Array.some(pkgs, (function (pkg) {
                    return Caml_obj.caml_equal(pkg, [
                                name + "/" + version + "@",
                                folder
                              ]);
                  }))) {
            return pkgs;
          } else {
            return $$Array.concat(pkgs, [[
                          name + "/" + version + "@",
                          folder
                        ]]);
          }
        }), []);
  var config = Task.flatMap(Task.fromResult(Result.seq2(Tuple.map2([
                    "CONAN_CONFIG_URL",
                    "CONAN_CONFIG_DIR"
                  ], Env.getError))), (function (param) {
          return Proc.run([
                      "conan",
                      "config",
                      "install",
                      param[0],
                      "-sf",
                      param[1]
                    ]);
        }));
  return Task.flatMap(Task.flatMap(config, (function (param) {
                    return Task.map(Task.fromResult(Result.seq3(Tuple.map3([
                                            "CONAN_LOGIN_USERNAME",
                                            "CONAN_LOGIN_PASSWORD",
                                            "CONAN_REPO_ALL"
                                          ], Env.getError))), (function (param) {
                                  return Proc.run([
                                              "conan",
                                              "user",
                                              param[0],
                                              "-p",
                                              param[1],
                                              "-r",
                                              param[2]
                                            ]);
                                }));
                  })), (function (param) {
                return Task.pool($$Array.map(exportPkgs, (function (param, param$1) {
                                  return Proc.run([
                                              "conan",
                                              "export",
                                              param[1],
                                              param[0]
                                            ]);
                                })), navigator.hardwareConcurrency);
              }));
}

function getBuildOrder(ints) {
  var locks = $$Array.map(ints, (function (param) {
          var match = param.base;
          return match.name + "-" + match.version + "-" + param.hash + ".lock";
        }));
  var bundle = $$Array.empty(locks) ? Task.to("") : Proc.run($$Array.concat([
              "conan",
              "lock",
              "bundle",
              "create",
              "--bundle-out=lock.bundle"
            ], locks));
  return Task.flatMap(Task.flatMap(bundle, (function (param) {
                    return Proc.run([
                                "conan",
                                "lock",
                                "bundle",
                                "build-order",
                                "lock.bundle",
                                "--json=build_order.json"
                              ]);
                  })), (function (param) {
                return Task.fromResult(Result.map($$File.read("build_order.json"), (function (content) {
                                  return $$Array.map(Json.$$Array.get(Json.parse(content)), (function (array) {
                                                return $$Array.map(Json.$$Array.get(array), Json.$$String.get);
                                              }));
                                })));
              }));
}

function getExtends(param) {
  var profile = param[0];
  var triple = List.fromArray($$String.split(profile, "-"));
  var arch;
  if (triple) {
    var match = triple.tl;
    if (match) {
      switch (match.hd) {
        case "armv8" :
            arch = {
              TAG: /* Ok */0,
              _0: "armv8"
            };
            break;
        case "wasm" :
        case "x86_64" :
            arch = {
              TAG: /* Ok */0,
              _0: "x86_64"
            };
            break;
        default:
          arch = {
            TAG: /* Error */1,
            _0: "Could not detect image arch for profile: " + profile
          };
      }
    } else {
      arch = {
        TAG: /* Error */1,
        _0: "Could not detect image arch for profile: " + profile
      };
    }
  } else {
    arch = {
      TAG: /* Error */1,
      _0: "Could not detect image arch for profile: " + profile
    };
  }
  var end = param[1] ? "-bootstrap" : "";
  return Result.map(arch, (function (arch) {
                return [".conan" + "-" + arch + end];
              }));
}

function getJob(ints, buildOrder) {
  return $$Array.flatMapWithIndex(buildOrder, (function (index, group) {
                return $$Array.flatMap(group, (function (pkg) {
                              var match = $$String.split(pkg, "@#");
                              var match$1;
                              if (match.length !== 2) {
                                match$1 = [
                                  "invalid-pkg",
                                  "invalid-rev"
                                ];
                              } else {
                                var pkg$1 = match[0];
                                var pkgRevision = match[1];
                                match$1 = [
                                  pkg$1,
                                  pkgRevision
                                ];
                              }
                              var pkgRevision$1 = match$1[1];
                              var pkg$2 = match$1[0];
                              var ints$1 = $$Array.filter(ints, (function (param) {
                                      var match = param.base;
                                      if (pkgRevision$1 === param.revision) {
                                        return pkg$2 === match.name + "/" + match.version;
                                      } else {
                                        return false;
                                      }
                                    }));
                              return $$Array.concat($$Array.map(ints$1, (function ($$int) {
                                                var group = buildOrder[index - 1 | 0];
                                                return Dict.to($$int.base.name + "/" + $$int.base.version + "@" + $$int.hash, {
                                                            extends: $$int.extends,
                                                            variables: Caml_option.some(getVariables($$int)),
                                                            image: undefined,
                                                            tags: undefined,
                                                            script: undefined,
                                                            needs: $$Array.uniq($$Array.concat($$int.base.needs, group !== undefined ? $$Array.map(group, (function (pkg) {
                                                                              var match = $$String.split(pkg, "@#");
                                                                              if (match.length !== 2) {
                                                                                return "invalid-pkg";
                                                                              } else {
                                                                                return match[0];
                                                                              }
                                                                            })) : [])),
                                                            services: undefined,
                                                            cache: undefined
                                                          });
                                              })), [Dict.to(pkg$2, {
                                                extends: undefined,
                                                variables: undefined,
                                                image: undefined,
                                                tags: ["x86_64"],
                                                script: ["echo"],
                                                needs: $$Array.map(ints$1, (function (foundPkg) {
                                                        return pkg$2 + "@" + foundPkg.hash;
                                                      })),
                                                services: undefined,
                                                cache: undefined
                                              })]);
                            }));
              }));
}

function getConanInstances($$int) {
  var version = $$int.version;
  var name = $$int.name;
  var repo = getRepo($$int.folder);
  var args = getArgs(name, $$int.modeInt);
  return Task.seq($$Array.map($$int.profiles, (function (profile) {
                    var $$extends = getExtends([
                          profile,
                          $$int.bootstrap
                        ]);
                    return Task.flatMap(Task.fromResult(Result.seq2([
                                        $$extends,
                                        repo
                                      ])), (function (param) {
                                  var repo = param[1];
                                  var $$extends = param[0];
                                  var hash = Hash.hashN({
                                        base: $$int,
                                        extends: $$extends,
                                        hash: "",
                                        revision: "",
                                        profile: profile,
                                        repo: repo,
                                        args: args
                                      }, 3);
                                  return Task.flatMap(Task.flatMap(Proc.run($$Array.concat([
                                                          "conan",
                                                          "lock",
                                                          "create",
                                                          "--ref=" + name + "/" + version,
                                                          "--build=" + name + "/" + version,
                                                          "--lockfile-out=" + name + "-" + version + "-" + hash + ".lock",
                                                          "-pr=" + profile
                                                        ], args)), (function (param) {
                                                    return Task.fromResult(Result.flatMap($$File.read(name + "-" + version + "-" + hash + ".lock"), (function (lock) {
                                                                      var ref = Json.$$Object.get(Json.$$Object.get(Json.$$Object.get(Json.$$Object.get(Json.parse(lock), "graph_lock"), "nodes"), "1"), "ref");
                                                                      if (typeof ref !== "number" && ref.TAG === /* String */0) {
                                                                        var revision = $$String.split(ref._0, "#")[1];
                                                                        if (revision !== undefined) {
                                                                          return {
                                                                                  TAG: /* Ok */0,
                                                                                  _0: revision
                                                                                };
                                                                        } else {
                                                                          return {
                                                                                  TAG: /* Error */1,
                                                                                  _0: "Invalid lock file: " + name + "-" + version + "-" + hash + ".lock"
                                                                                };
                                                                        }
                                                                      }
                                                                      return {
                                                                              TAG: /* Error */1,
                                                                              _0: "Invalid lock file: " + name + "-" + version + "-" + hash + ".lock"
                                                                            };
                                                                    })));
                                                  })), (function (revision) {
                                                return Task.to({
                                                            base: $$int,
                                                            extends: $$extends,
                                                            hash: hash,
                                                            revision: revision,
                                                            profile: profile,
                                                            repo: repo,
                                                            args: args
                                                          });
                                              }));
                                }));
                  })));
}

function getJobs(ints) {
  var ints$1 = $$Array.filter(ints, (function ($$int) {
          return $$int.mode === "conan";
        }));
  return Task.flatMap(Task.flatMap(init(ints$1), (function (param) {
                    return Task.map(Task.pool($$Array.map(ints$1, (function ($$int, param) {
                                          return getConanInstances($$int);
                                        })), navigator.hardwareConcurrency), $$Array.flatten);
                  })), (function (ints) {
                if ($$Array.empty(ints)) {
                  return Task.to([]);
                } else {
                  return Task.map(getBuildOrder(ints), (function (buildOrder) {
                                return getJob(ints, buildOrder);
                              }));
                }
              }));
}

var hashLength = 3;

export {
  hashLength ,
  hashN ,
  getArgs ,
  getRepo ,
  getVariables ,
  init ,
  getBuildOrder ,
  getExtends ,
  getJob ,
  getConanInstances ,
  getJobs ,
  
}
/* File Not a pure module */