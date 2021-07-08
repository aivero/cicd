//import * as github from "@actions/github";
//import { RequestParameters } from "@octokit/types";
//import simpleGit, { SimpleGit } from "simple-git";
//import { inspect } from "util";
//import yaml from "yaml";

//import * as yaml from "encoding/yaml";

//import { parse, createVisitor } from "python-ast";
import { modeRunner } from "./src/modes/mode.ts";
import { run } from "./src/util.ts"

run(modeRunner);
