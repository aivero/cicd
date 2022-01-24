@module("path") @variadic external join: array<string> => string = "join"
@module("path") external basename: string => string = "basename"
@module("path") external dirname: string => string = "dirname"

type dirEntry = {
	name: string,
  isFile: bool,
  isDirectory: bool,
  isSymlink: bool,
}

@val external _read: string => Js.Array2.array_like<dirEntry> = "Deno.readDirSync"

let read = (path) => path->_read->Js.Array2.from