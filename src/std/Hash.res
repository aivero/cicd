@module("hash") external hash: 'a => string = "default"

let hashN = (data, n) => data->hash->String.sub(0, n)