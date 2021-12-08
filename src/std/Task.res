type t<+'a> = Js.Promise.t<'a>
@new external new: (('a => unit) => unit) => t<'a> = "Promise"

type promiseFn<'a, +'b> = 'a => Js.Promise.t<'b>

let resolve = Js.Promise.resolve
let reject = Js.Promise.reject
let catch = (a, f) => Js.Promise.catch(f, a)
let map = (a, fn) => Js.Promise.then_(v => v->fn->resolve, a)
let flatMap = (a, fn) => Js.Promise.then_(fn, a)
let catchResolve = (a, fn) => a->catch(e => e->fn->resolve)

let sleep = (a, ms) => a->flatMap(res => (resolve => Js.Global.setTimeout(_ => resolve(res), ms)->ignore)->new)


@scope("Promise") @val external all: array<t<'a>> => t<array<'a>> = "all"
@scope("Promise") @val external all2: ((t<'a>, t<'b>)) => t<('a, 'b)> = "all"
@scope("Promise") @val external all3: ((t<'a>, t<'b>, t<'c>)) => t<('a, 'b, 'c)> = "all"