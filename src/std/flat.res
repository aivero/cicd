let array = (a: array<result<'a, 'error>>) => {
  a->Js.Array.reduce((a, e) =>
    switch (a, e) {
    | (Ok(a), Ok(e)) => Ok(Array.concat([e], a))
    | (_, Error(e)) => Error(e)
    | _ => Error("This should not happen")
    }
  , Ok([]), _)
}

let task = (to: Task.t<result<Task.t<'a>, 'error>>) => {
  to->Task.flatMap(r => {
		switch r {
		| Ok(ti) => ti
		| Error(error) => Error(error)->Task.resolve
		}
	})
}