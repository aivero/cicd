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

let getMode = (int: Instance.t) => {
  switch (int.mode, int.folder) {
  | (Some(mode), _) => parseMode(mode)
  | (_, Some(folder)) if File.exists(Path.join([folder, "conanfile.py"])) => #conan
  | (_, Some(folder)) if File.exists(Path.join([folder, "Dockerfile"])) => #docker
  | (_, _) => #command
  }
}

let load = ints => {
  ints->Result.map(ints => {
    Task.all([Command.getJobs(ints), Conan.getJobs(ints)])
    ->Task.map(jobs => jobs->Flat.array->Result.map(Array.concatMany))
    ->(b => b)
  })
  //switch (Instance.zip(int), getMode(int)) {
  //| (Ok(zip), #conan) => Conan.getJobs(zip)
  //| (Ok(zip), #command) => Command.getJobs(zip)
  //| JobMode.Docker => getConanDockerJobs(conf)
  //| JobMode.ConanInstallTarball => getConanDockerJobs(conf)
  //| JobMode.ConanInstallScript => getConanDockerJobs(conf)
  //}
}
