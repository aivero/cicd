type t<'a, 'error> = Task.t<Result.t<'a, 'error>>
let resolve = (t) => t->Ok->Task.resolve

let flatten = (to: t<t<'a, 'error>, 'error>) => {
  to->Task.flatMap(r => {
    switch r {
    | Ok(ti) => ti
    | Error(error) => Error(error)->Task.resolve
    }
  })
}

let map = (a, fn) => a->Task.map(res => res->Result.map(fn))
let flatMap = (a, fn) => a->Task.map(res => res->Result.map(fn))->flatten


let seq = (a: array<t<'a, 'error>>) => a->Task.seq->Task.map(Result.seq)

let seq2 = ((a1: t<'a, 'error>, a2: t<'b, 'error>)) => (a1, a2)->Task.seq2->Task.map(Result.seq2)

let seq3 = ((a1: t<'a, 'error>, a2: t<'b, 'error>, a3: t<'c, 'error>)) =>
  (a1, a2, a3)->Task.seq3->Task.map(Result.seq3)

let seq4 = ((a1: t<'a, 'error>, a2: t<'b, 'error>, a3: t<'c, 'error>, a4: t<'d, 'error>)) =>
  (a1, a2, a3, a4)->Task.seq4->Task.map(Result.seq4)

let rec pool = (tasks: array<unit => Task.t<result<'a, string>>>, count): Task.t<
  result<array<'a>, string>,
> => {
  let curTasks =
    tasks
    ->Array.slice(~offset=0, ~len=count)
    ->Array.map(f => (resolve => resolve(f()))->Task.new)
    ->Task.seq
  let rest = tasks->Array.slice(~offset=count, ~len=tasks->Array.length - count)
  `pool: ${rest->Array.length->Int.toString}`->Console.log
  curTasks
  ->Task.flatMap(res1 => {
    let tasks = res1->seq
    tasks->map(res1 =>
      switch rest->Array.length {
      | 0 => res1->resolve
      | _ =>
        rest->pool(count)->map(res2 => [res1, res2]->Array.flatten)
      }
    )
  })
  ->flatten
}

