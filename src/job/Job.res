type mode = [
  | #conan
  | #docker
  | #command
  | #"conan-install-tarball"
  | #"conan-install-script"
]

let parseMode = str => {
  switch str {
  | "conan" => #conan
  | "docker" => #docker
  | "conan-install-tarball" => #"conan-install-tarball"
  | "conan-install-script" => #"conan-install-script"
  | _ => #command
  }
}

let load = ints => {
  Task.seq(
    [Command.getJobs, Conan.getJobs, Docker.getJobs]->Array.map(f => ints->f),
  )->Task.map(jobs => jobs->Result.seq->Result.map(Array.flatten))
}
