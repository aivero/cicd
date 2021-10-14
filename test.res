/*

let read = F.flow(
    util.getFileData,
)



// eslint-disable-next-line functional/no-expression-statement
void read("devops.yml")().then((either) => E.fold(console.log, console.log)(either));
*/

F.pipe(
    manual.findJobs(),
    //U.exec(["ls"]),
    T.map(E.fold(console.log, console.log))
)()
