let array = (a: array<result<'a, 'error>>) => {
  a->Js.Array2.reduce((a, e) =>
    switch (a, e) {
    | (Ok(a), Ok(e)) => Ok(Array.concat([e], a))
    | (Error(e), _) => Error(e)
    | (_, Error(e)) => Error(e)
    }
  , Ok([]))
}

let task = (to: Task.t<result<Task.t<'a>, 'error>>) => {
  to->Task.flatMap(r => {
		switch r {
		| Ok(ti) => ti
		| Error(error) => Error(error)->Task.resolve
		}
	})
}

/*
let taskArray = (to: Task.t<array<Task.t<'a>>>) => {
  to->Task.flatMap(r => {
		switch r {
		| Ok(ti) => ti
		| Error(error) => Error(error)->Task.resolve
		}
	})
}*/