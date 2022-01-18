let result = (a: array<result<'a, 'error>>) => {
  a->Js.Array2.reduce((a, e) =>
    switch (a, e) {
    | (Ok(a), Ok(e)) => Ok(Array.concat([e], a))
    | (Error(e), _) => Error(e)
    | (_, Error(e)) => Error(e)
    }
  , Ok([]))
}

let option = (a: array<option<'a>>) => {
  a->Js.Array2.reduce((a, e) =>
    switch (a, e) {
    | (Some(a), Some(e)) => Some(Array.concat([e], a))
    | (None, _) => None
    | (_, None) => None
    }
  , Some([]))
}