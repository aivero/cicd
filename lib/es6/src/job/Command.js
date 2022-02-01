// Generated by ReScript, PLEASE EDIT WITH CARE

import * as Dict from "../std/Dict.js";
import * as Task from "../std/Task.js";
import * as $$Array from "../std/Array.js";
import * as Profile from "../Profile.js";

function getJobs(ints) {
  return Task.to($$Array.flatMap($$Array.filter(ints, (function ($$int) {
                        return $$int.mode === "command";
                      })), (function (param) {
                    var image = param.image;
                    var script = param.script;
                    var profiles = param.profiles;
                    var needs = param.needs;
                    var folder = param.folder;
                    var version = param.version;
                    var name = param.name;
                    return $$Array.concat($$Array.map(profiles, (function (profile) {
                                      return Dict.to(name + "/" + version + "-" + profile, {
                                                  extends: undefined,
                                                  variables: undefined,
                                                  image: Profile.getImage(profile, image),
                                                  tags: undefined,
                                                  script: $$Array.concat(["cd " + folder], script),
                                                  needs: $$Array.uniq(needs),
                                                  services: undefined,
                                                  cache: undefined
                                                });
                                    })), [Dict.to(name + "/" + version, {
                                      extends: undefined,
                                      variables: undefined,
                                      image: undefined,
                                      tags: undefined,
                                      script: ["echo"],
                                      needs: $$Array.map(profiles, (function (profile) {
                                              return name + "/" + version + "-" + profile;
                                            })),
                                      services: undefined,
                                      cache: undefined
                                    })]);
                  })));
}

export {
  getJobs ,
  
}
/* No side effect */