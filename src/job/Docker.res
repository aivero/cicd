let getJobs = (zips: array<Instance.zip>) => {
  zips->Array.map(zip => {
    let int = zip.int
    let args = int->Conan.getArgs->Array.joinWith(" ", str => str)
    let tag = switch (int.name, int.tag, int.branch) {
    | (Some(name), Some(tag), Some(branch)) => `${tag}:${branch}`
    | (Some(name), _, Some(branch)) =>
      `ghcr.io/aivero/${name}/${zip.profile->Js.String2.toLowerCase}:${branch}`
    }
    let install = switch (int.folder, int.branch, int.conanInstall) {
    | (Some(folder), Some(branch), Some(conanInstall)) =>
      conanInstall->Array.map(pkg => [
        `mkdir -p ${folder}/install || true`,
        `conan install ${args}${pkg}/${branch}@ -if ${folder}/install/${pkg}`,
      ])
    | _ => []
    }
    switch (int.cmds, zip->Detect.getImage) {
    | (Some(cmds), Ok(image)) =>
      (
        {
          Ok({
            name: "foo",
            script: Some(cmds),
            image: Some(image),
            needs: switch zip.int.req {
            | Some(needs) => needs
            | None => []
            },
          })
        }: result<Job_t.t, string>
      )
    | (_, Error(err)) => Error(err)
    | (None, _) => Error("No commands specified")
    }
  })

  /*
  
  // Replace prefix and create tarball
  if (conf.conanInstall) {
    for (let pkg of conf.conanInstall) {
      script = script.concat([
        `sed -i s#PREFIX=.*#PREFIX=/${conf.subdir}/${pkg}# ${conf.folder}/install/${pkg}/${conf.subdir}/dddq_environment.sh`,
      ]);
    }
    script = script.concat([
      `tar -cvjf ${conf.folder}/${conf.name}-${conf.branch}.tar.bz2 -C ${conf.folder}/install/ ${conf.name}`,
    ]);
  }
 */

  /*


  if (conf.docker.platform) {
    payload.docker.platform = conf.docker.platform;
  } else {
    payload.docker.platform = this.getDockerPlatform(
      profile.toLowerCase(),
    );
  }

  if (conf.docker.dockerfile) {
    payload.docker.dockerfile = `${conf.folder}/${conf.docker.dockerfile}`;
  } else {
    payload.docker.dockerfile = `${conf.folder}/docker/${profile}.Dockerfile`;
  }

  return payloads;
 */
}