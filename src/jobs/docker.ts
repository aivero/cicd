import * as E from "fun/either.ts";
import { getConanJobs } from "./conan.ts";
import { Job } from "~/jobs/job.ts";
import { Config } from "~/config.ts";

export const getConanDockerJobs = (
  conf: Config,
): E.Either<Error, Job[]> => {
  const jobs = getConanJobs(conf);

  return jobs;
  /*

  // Conan install all specified conan packages to a folder prefixed with install-
  if (conf.conanInstall) {
    for (const conanPkgs of conf.conanInstall) {
      script = script.concat([
        `mkdir -p ${conf.folder}/install || true`,
        `conan install ${args}${conanPkgs}/${conf.branch}@ -if ${conf.folder}/install/${conanPkgs}`,
      ]);
    }
  }

  // Add commands
  if (conf.mode == InstanceMode.ConanInstallScript) {
    const scripts = conf.script || [];
    script = script.concat(scripts);
  }

  // Replace prefix and create tarball
  if (conf.conanInstall) {
    for (const pkg of conf.conanInstall) {
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
  conf.docker = conf.docker || {};
  payload.docker = payload.docker || {};
  if (conf.docker.tag) {
    // todo: consider tagging just like conan: hash and then a second tag one on the git branch/tag
    payload.docker.tag = `${conf.docker.tag}:${conf.branch}`;
  } else {
    payload.docker.tag =
      `ghcr.io/aivero/${conf.name}/${profile.toLowerCase()}:${conf.branch}`;
  }

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
};
