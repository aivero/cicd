type t
@new external new: () => t = "TextDecoder"
@send external decode: (t, Js.TypedArray2.Uint8Array.t) => string = "decode"

