let option = (a: array<option<'a>>) => {
  a->Js.Array2.reduce((a, e) =>
    switch (a, e) {
    | (Some(a), Some(e)) => Some(Array.concat(a, [e]))
    | (None, _) => None
    | (_, None) => None
    }
  , Some([]))
}

let option2 = ((a1: option<'a>, a2: option<'b>)) => {
  switch (a1, a2) {
  | (Some(a1), Some(a2)) => Some(a1, a2)
  | (None, _) => None
  | (_, None) => None
  }
}

let option3 = ((a1: option<'a>, a2: option<'b>, a3: option<'c>)) => {
  switch (a1, a2, a3) {
  | (Some(a1), Some(a2), Some(a3)) => Some(a1, a2, a3)
  | (None, _, _) => None
  | (_, None, _) => None
  | (_, _, None) => None
  }
}

let option4 = ((a1: option<'a>, a2: option<'b>, a3: option<'c>, a4: option<'d>)) => {
  switch (a1, a2, a3, a4) {
  | (Some(a1), Some(a2), Some(a3), Some(a4)) => Some(a1, a2, a3, a4)
  | (None, _, _, _) => None
  | (_, None, _, _) => None
  | (_, _, None, _) => None
  | (_, _, _, None) => None
  }
}

let result = (a: array<result<'a, 'error>>) => {
  a->Js.Array2.reduce((a, e) =>
    switch (a, e) {
    | (Ok(a), Ok(e)) => Ok(Array.concat(a, [e]))
    | (Error(e), _) => Error(e)
    | (_, Error(e)) => Error(e)
    }
  , Ok([]))
}

let result2 = ((a1: result<'a, 'error>, a2: result<'b, 'error>)) => {
  switch (a1, a2) {
  | (Ok(a1), Ok(a2)) => Ok(a1, a2)
  | (Error(e), _) => Error(e)
  | (_, Error(e)) => Error(e)
  }
}

let result3 = ((a1: result<'a, 'error>, a2: result<'b, 'error>, a3: result<'c, 'error>)) => {
  switch (a1, a2, a3) {
  | (Ok(a1), Ok(a2), Ok(a3)) => Ok(a1, a2, a3)
  | (Error(e), _, _) => Error(e)
  | (_, Error(e), _) => Error(e)
  | (_, _, Error(e)) => Error(e)
  }
}

let result4 = ((a1: result<'a, 'error>, a2: result<'b, 'error>, a3: result<'c, 'error>, a4: result<'d, 'error>)) => {
  switch (a1, a2, a3, a4) {
  | (Ok(a1), Ok(a2), Ok(a3), Ok(a4)) => Ok(a1, a2, a3, a4)
  | (Error(e), _, _, _) => Error(e)
  | (_, Error(e), _, _) => Error(e)
  | (_, _, Error(e), _) => Error(e)
  | (_, _, _, Error(e)) => Error(e)
  }
}