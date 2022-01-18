let result = (a: array<result<'a, 'error>>) => {
  a->Js.Array2.reduce((a, e) =>
    switch (a, e) {
    | (Ok(a), Ok(e)) => Ok(Array.concat(a, [e]))
    | (Error(e), _) => Error(e)
    | (_, Error(e)) => Error(e)
    }
  , Ok([]))
}

let result2 = (a1: result<'a, 'error>, a2: result<'b, 'error>) => {
  switch (a1, a2) {
  | (Ok(a1), Ok(a2)) => Ok(a1, a2)
  | (Error(e), _) => Error(e)
  | (_, Error(e)) => Error(e)
  }
}

let option = (a: array<option<'a>>) => {
  a->Js.Array2.reduce((a, e) =>
    switch (a, e) {
    | (Some(a), Some(e)) => Some(Array.concat(a, [e]))
    | (None, _) => None
    | (_, None) => None
    }
  , Some([]))
}

let option2 = (a1: option<'a>, a2: option<'b>) => {
  switch (a1, a2) {
  | (Some(a1), Some(a2)) => Some(a1, a2)
  | (None, _) => None
  | (_, None) => None
  }
}