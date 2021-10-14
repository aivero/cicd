@module("path") @variadic external join: array<string> => string = "join"
@module("path") external basename: string => string = "basename"
@module("path") external dirname: string => string = "dirname"