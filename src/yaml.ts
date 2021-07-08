import * as E from "fun/either.ts";
import * as F from "fun/fns.ts";
import * as yaml from "std/encoding/yaml.ts"

export type YamlArray = readonly Yaml[];
export type YamlRecord = {
  readonly [key: string]: Yaml
};


export type Yaml = boolean | number | string | null | YamlArray | YamlRecord


export const parseYaml = (s: string): E.Either<Error, Yaml> => {
  return E.tryCatch(() => yaml.parse(s) as Yaml, F.flow(String, Error))
}


export const stringifyYaml = (u: Record<string, unknown>): E.Either<Error, string> =>
  E.tryCatch(() => {
    return yaml.stringify(u)
  }, () => Error('Converting unsupported structure to YAML'))