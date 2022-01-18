let array = Array.concatMany

/*
let taskArray = (to: Task.t<array<Task.t<'a>>>) => {
  to->Task.flatMap(r => {
		switch r {
		| Ok(ti) => ti
		| Error(error) => Error(error)->Task.resolve
		}
	})
}*/