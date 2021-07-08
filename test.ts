/*
import * as util from "./src/util.ts"
import * as TE from 'fun/task_either.ts';
import * as IOE from 'fun/io_either.ts';
import * as F from 'fun/fns.ts';
import * as config from "./src/config.ts";

const read = F.flow(
    util.getFileData,
)



// eslint-disable-next-line functional/no-expression-statement
void read("devops.yml")().then((either) => E.fold(console.log, console.log)(either));
*/
import * as E from "fun/either.ts"
import * as TE from "fun/task_either.ts"
import * as T from "fun/task.ts"
import * as F from 'fun/fns.ts';

import * as U from "~/util.ts"
import manual from '~/modes/manual.ts'
F.pipe(
    manual.findJobs(),
    //U.exec(["ls"]),
    T.map(E.fold(console.log, console.log))
)()