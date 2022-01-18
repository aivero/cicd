type t<'a, 'error> = Task.t<Result.t<'a, 'error>>
let resolve = Js.Promise.resolve
let map = (a, fn) => a->Task.map(res => res->Result.map(fn))
let flatMap = (a, fn) => a->Task.map(res => res->Result.flatMap(fn))

let flatten = (to: t<<t<'a, 'error>, 'error>) => {
  to->Task.flatMap(r => {
		switch r {
		| Ok(ti) => ti
		| Error(error) => Error(error)->Task.resolve
		}
	})
}

let rec pool = (tasks: array<unit => Task.t<result<'a, string>>>, count): Task.t<
  result<array<'a>, string>,
> => {
  let curTasks =
    tasks
    ->Array.slice(~offset=0, ~len=count)
    ->Array.map(f => (resolve => resolve(f()))->Task.new)
    ->Task.all
  let rest = tasks->Array.slice(~offset=count, ~len=tasks->Array.length - count)
  `pool: ${rest->Array.length->Int.toString}`->Js.Console.log
  curTasks
  ->Task.flatMap(res1 => {
    let tasks = res1->Task.all->Task.map(Seq.array)
    tasks->map(res1 =>
      switch rest->Array.length {
      | 0 => Ok(res1)->Task.resolve
      | _ =>
        rest
        ->pool(count)
        ->Task.map(res2 => res2->Result.map(res2 => [res1, res2]->Array.concatMany))
      }
    )
  })
  ->flatten
}
