import { IO } from "fun/io.ts"

export default (s: unknown): IO<void> => () => console.log(s)
