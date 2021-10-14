@val external _read: string => string = "Deno.readTextFileSync"
@module("fs") external exists: string => bool = "existsSync"

let read = (path: string) => exists(path) ? Ok(_read(path)) : Error(`${path} does not exist`);
