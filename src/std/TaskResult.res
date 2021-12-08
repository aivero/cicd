
let resolve = Js.Promise.resolve
let map = (a, fn) => a->Task.map(res => res->Result.map(fn))
let flatMap = (a, fn) => a->Task.map(res => res->Result.flatMap(fn))
