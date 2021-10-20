open Instance

@send external toString: 'a => string = "toString"

let getArgs = (int: Instance.t) => {
  let args = switch Env.get("args") {
  | Some(args) => args->Js.String2.split(" ")
  | None => []
  }

  let sets = switch (int.name, int.settings) {
  | (Some(name), Some(settings)) =>
    settings
    ->Js.Dict.entries
    ->Array.map(((key, val)) => (
      key,
      val->toString == "true" ? "True" : val->toString == "false" ? "False" : val,
    ))
    ->Array.map(((key, val)) => `-s ${name}:${key}=${val}`)
  | _ => []
  }

  let opts = switch (int.name, int.options) {
  | (Some(name), Some(options)) =>
    options
    ->Js.Dict.entries
    ->Array.map(((key, val)) => (
      key,
      val->toString == "true" ? "True" : val->toString == "false" ? "False" : val,
    ))
    ->Array.map(((key, val)) => `-o ${name}:${key}=${val}`)
  | _ => []
  }

  Array.concatMany([args, sets, opts]) //->Array.joinWith(" ", str => str)
}

let getRepo = (int: Instance.t) => {
  [int.folder->Option.getExn, "conanfile.py"]
  ->Path.join
  ->File.read
  ->Result.map(content =>
    content->Js.String2.includes("Proprietary") ? "$CONAN_REPO_INTERNAL" : "$CONAN_REPO_INTERNAL"
  )
}

let getCmds = ({int, profile}: Instance.zip): array<string> => {
  let initCmds = [
    `conan config install $CONAN_CONFIG_URL -sf $CONAN_CONFIG_DIR`,
    `conan user $CONAN_LOGIN_USERNAME -p $CONAN_LOGIN_PASSWORD -r $CONAN_REPO_ALL`,
    `conan user $CONAN_LOGIN_USERNAME -p $CONAN_LOGIN_PASSWORD -r $CONAN_REPO_INTERNAL`,
    `conan user $CONAN_LOGIN_USERNAME -p $CONAN_LOGIN_PASSWORD -r $CONAN_REPO_PUBLIC`,
    `conan config set general.default_profile=${profile}`,
  ]

  let repo = getRepo(int)
  let args = getArgs(int)->Array.joinWith(" ", str => str)
  let cmds = switch (int.name, int.version, int.folder, repo) {
  | (Some(name), Some(version), Some(folder), Ok(repo)) => {
      let createPkg = [`conan create ${args}${folder} ${name}/${version}@`]
      let createDbg = [`conan create ${args}${folder} ${name}-dbg/${version}@`]
      let uploadPkg = [`conan upload ${name}/${version}@ --all -c -r ${repo}`]
      let uploadDbg = switch int.debugPkg {
      | Some(true) => [`conan upload ${name}-dbg/${version}@ --all -c -r ${repo}`]
      | _ => []
      }
      Array.concatMany([createPkg, createDbg, uploadPkg, uploadDbg])
    }
  | _ => []
  }

  Array.concatMany([initCmds, cmds, [`conan remove --locks`, `conan remove * -f`]])
}

type conanInfo = {
  revision: string,
  reference: string,
}

type pkgInfo = {
  info: conanInfo,
  int: Instance.t,
  profile: string,
  mode: Instance.mode,
}

external toConanInfo: 'a => array<conanInfo> = "%identity"

let getInfo = ({int, profile, mode}: Instance.zip) => {
  switch (int.name, int.version) {
  | (Some(name), Some(version)) =>
    Proc.run(
      Array.concatMany([
        ["conan", "info", "-j", `${name}-${version}-${profile}.json`, `-pr=${profile}`],
        int->getArgs,
        [`${name}/${version}@`],
      ]),
    )->Task.map(res => {
      res->Result.flatMap(_ =>
        switch File.read(`${name}-${version}-${profile}.json`) {
        | Ok(output) =>
          output
          ->Js.Json.parseExn
          ->toConanInfo
          ->Js.Array2.find(e => e.reference == `${name}/${version}`)
          ->(
            find =>
              switch find {
              | Some(info) => Ok({int: int, profile: profile, info: info, mode: mode})
              | None => Error(`Couldn't find info for: ${name}/${version} (${profile})`)
              }
          )

        | Error(e) => Error(e)
        }
      )
    })
  | _ => Error("Name or version not defined")->Task.resolve
  }
}

@send external toLockfile: 'a => array<array<string>> = "%identity"

let exportPkg = int => {
  switch (int.name, int.version, int.folder) {
  | (Some(name), Some(version), Some(folder)) =>
    Proc.run(["conan", "export", folder, `${name}/${version}@`])
  | _ => Task.resolve(Error("Name, version or folder not defined"))
  }
}

let getLockFile = (triples: Task.t<result<array<pkgInfo>, string>>) => {
  triples
  ->Task.map(res => {
    res->Result.map(triples =>
      triples
      ->Array.map(triple => {
        switch (triple.int.name, triple.int.version) {
        | (Some(name), Some(version)) =>
          Proc.run(
            [
              "conan",
              "lock",
              "create",
              `--ref=${name}/${version}`,
              `--lockfile-out=${name}-${version}-${triple.info.revision}.lock`,
              `-pr=${triple.profile}`,
            ]->Array.concat(triple.int->getArgs),
          )->Task.map(output =>
            switch output {
            | Ok(_) => Ok(triple)
            | Error(e) => Error(e)
            }
          )
        | _ => Task.resolve(Error("This should not happen"))
        }
      })
      ->Task.all
      ->Task.map(Flat.array)
    )
  })
  ->Flat.task
  ->Task.map(res => {
    res->Result.map(triples => {
      let locks = triples->Array.map(triple => {
        switch (triple.int.name, triple.int.version) {
        | (Some(name), Some(version)) => `${name}-${version}-${triple.info.revision}.lock`
        | _ => ""
        }
      })
      Proc.run(
        ["conan", "lock", "bundle", "create", "--bundle-out=lock.bundle"]->Array.concat(locks),
      )->Task.map(output =>
        switch output {
        | Ok(_) => Ok(triples)
        | Error(e) => Error(e)
        }
      )
    })
  })
  ->Flat.task
  ->Task.map(res => {
    res->Result.map(_ => {
      Proc.run([
        "conan",
        "lock",
        "bundle",
        "build-order",
        "lock.bundle",
        "--json=build_order.json",
      ])->Task.map(output =>
        switch output {
        | Ok(_) => res
        | Error(e) => Error(e)
        }
      )
    })
  })
  ->Flat.task
  ->Task.map(res => {
    res->Result.flatMap(_ => {
      File.read("build_order.json")
      ->Result.map(content => content->Js.Json.parseExn->toLockfile)
    })
  })
}

let getJob = (buildOrder, pkgInfos) => {
  buildOrder
  ->Array.mapWithIndex((index, group) => {
    group
    ->Array.map(pkg => {
      let revision = (pkg->Js.String2.split("#"))[1]
      let foundPkg = pkgInfos->Js.Array2.find(e => {
        switch revision {
        | Some(revision) if revision == e.info.revision => true
        | _ => false
        }
      })
      switch foundPkg {
      | Some({int, profile, mode}) =>
        switch {int: int, profile: profile, mode: mode}->Detect.getImage {
        | Ok(image) =>
          Ok(
            (
              {
                name: pkg,
                script: {int: int, profile: profile, mode: mode}->getCmds,
                image: image,
                needs: switch int.needs {
                | Some(needs) => needs
                | None => []
                }->Array.concat(switch buildOrder[index-1] {
                | Some(group) => group
                | None => []
                }),
              }: Job_t.t
            ),
          )
        | Error(err) => Error(err)
        }
      | None => Error(`Couldn't find package: ${pkg}`)
      }
    })
    ->Flat.array
  })
  ->Flat.array
  ->Result.map(Array.concatMany)
}

let getJobs = (zips: array<Instance.zip>) => {
  let zips = zips->Js.Array2.filter(zip => zip.mode == #conan)
  let pkgInfos =
    zips
    ->Array.map(zip => zip.int->exportPkg)
    ->Task.all
    ->Task.flatMap(_ => {
      zips->Array.map(getInfo)->Task.all->Task.map(Flat.array)
    })
  let lockfile = pkgInfos->getLockFile
  Task.all2((pkgInfos, lockfile))->Task.map(((pkgInfos, lockfile)) => {
    switch (pkgInfos, lockfile) {
    | (Ok(pkgInfos), Ok(lockfile)) => lockfile->getJob(pkgInfos)
    | (Error(e), _) => Error(e)
    | (_, Error(e)) => Error(e)
    }
  })
}