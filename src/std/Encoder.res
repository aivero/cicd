type t
@new external new: () => t = "TextEncoder"
@send external encode: (t, string) => Js.TypedArray2.Uint8Array.t = "encode"