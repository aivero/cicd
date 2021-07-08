import * as E from "fun/either.ts";
import { Config } from "~/config.ts"
export const getDockerImage = (conf: Config) => (profile: string): E.Either<Error, string> => {
  // Base Conan image
  const base = "aivero/conan:";

  const os = profile.includes("musl")
    ? "alpine"
    : profile.includes("linux") || profile.includes("wasi")
      ? "bionic"
      : profile.includes("windows")
        ? "windows"
        : profile.includes("macos")
          ? "macos"
          : Error("Could not detect image os")

  // Arch options
  const arch = profile.includes("x86_64") || profile.includes("wasm")
    ? "x86_64"
    : profile.includes("armv8")
      ? "armv8"
      : Error("Could not detect image arch")

  // Handle bootstrap packages
  const end = conf.bootstrap
    ? "-bootstrap"
    : "";

  return E.right(`${base}${os}-${arch}${end}`);
};

export const getRunnerTags = (profile: string): E.Either<Error, string[]> => {
  // Arch options
  return profile.includes("x86_64") || profile.includes("wasm")
    ? E.right(["X64", "aws"])
    : profile.includes("armv8")
      ? E.right(["ARM64", "aws"])
      : E.left(Error("Could detect runner tags for profile"));
};

// Parse the profile name to a docker/buildx conform string as per
// https://github.com/docker/buildx#---platformvaluevalue
export const getDockerPlatform = (profile: string): E.Either<Error, string> => {
  const os = profile.includes("linux")
    ? "linux"
    : profile.includes("windows")
      ? Error(`Windows builds are not yet supported`)
      : profile.includes("macos")
        ? Error(`MacOS / Darwin builds are not yet supported`)
        : Error(`Could not parse profile ${profile} to an os.`);

  const arch = profile.includes("armv8") || profile.includes("arm64")
    ? "arm64"
    : profile.includes("armv7") || profile.includes("armhf")
      ? "arm/v7"
      : profile.includes("86_64") || profile.includes("86-64")
        ? "amd64"
        : Error(`Could not parse profile ${profile} to an arch.`);

  return E.right(`${os} /${arch}`);
};
