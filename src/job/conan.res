open Instance

@send external toString: 'a => string = "toString"

type conanInfo = {
  revision: string,
  reference: string,
}

type pkgInfo = {
  info: conanInfo,
  int: Instance.t,
  profile: string,
  mode: Instance.mode,
  hash: string,
}

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

external toConanInfo: 'a => array<conanInfo> = "%identity"

let getInfo = ({int, profile, mode}: Instance.zip) => {
  switch (int.name, int.version) {
  | (Some(name), Some(version)) => {
      let hash = Hash.hash({int: int, profile: profile, mode: mode})
      Proc.run(
        Array.concatMany([
          ["conan", "info", "-j", `${name}-${version}-${hash}.json`, `-pr=${profile}`],
          int->getArgs,
          [`${name}/${version}@`],
        ]),
      )->Task.map(res => {
        res->Result.flatMap(_ =>
          switch File.read(`${name}-${version}-${hash}.json`) {
          | Ok(output) =>
            output
            ->Js.Json.parseExn
            ->toConanInfo
            ->Js.Array2.find(e => e.reference == `${name}/${version}`)
            ->(
              find =>
                switch find {
                | Some(info) => Ok({int: int, profile: profile, info: info, mode: mode, hash: hash})
                | None => Error(`Couldn't find info for: ${name}/${version} (${profile})`)
                }
            )

          | Error(e) => Error(e)
          }
        )
      })
    }
  | _ => Error("Name or version not defined")->Task.resolve
  }
}

@send external toLockfile: 'a => array<array<string>> = "%identity"

let conanInit = (zips: array<Instance.zip>) => {
  let (url, dir) = switch (Env.get("CONAN_CONFIG_URL"), Env.get("CONAN_CONFIG_DIR")) {
  | (Some(url), Some(dir)) => (url, dir)
  | _ => ("", "")
  }
  let config = Proc.run([
    "conan",
    "config",
    "install",
    url,
    "-sf",
    dir,
  ])
  config->Task.flatMap(config =>
    switch config {
    | Ok(_) =>
      zips
      ->Array.map(zip => {
        switch (zip.int.name, zip.int.version, zip.int.folder) {
        | (Some(name), Some(version), Some(folder)) =>
          Proc.run(["conan", "export", folder, `${name}/${version}@`])
        | _ => Task.resolve(Error("Name, version or folder not defined"))
        }
      })
      ->Task.all
      ->Task.map(Flat.array)
    | Error(error) => Error(error)->Task.resolve
    }
  )
}

let getLockFile = (pkgInfos: Task.t<result<array<pkgInfo>, string>>) => {
  pkgInfos
  ->Task.map(res => {
    res->Result.map(pkgInfos =>
      pkgInfos
      ->Array.map(pkgInfo => {
        switch (pkgInfo.int.name, pkgInfo.int.version) {
        | (Some(name), Some(version)) =>
          Proc.run(
            [
              "conan",
              "lock",
              "create",
              `--ref=${name}/${version}`,
              `--lockfile-out=${name}-${version}-${Hash.hash(pkgInfo)}.lock`,
              `-pr=${pkgInfo.profile}`,
            ]->Array.concat(pkgInfo.int->getArgs),
          )->Task.map(output =>
            switch output {
            | Ok(_) => Ok(pkgInfo)
            | Error(e) => Error(e)
            }
          )
        | _ => Error("This should not happen")->Task.resolve
        }
      })
      ->Task.all
      ->Task.map(Flat.array)
    )
  })
  ->Flat.task
  ->Task.map(res => {
    res->Result.map(pkgInfos => {
      let locks = pkgInfos->Array.map(pkgInfo => {
        switch (pkgInfo.int.name, pkgInfo.int.version) {
        | (Some(name), Some(version)) => `${name}-${version}-${Hash.hash(pkgInfo)}.lock`
        | _ => ""
        }
      })
      locks->Js.Console.log
      locks->Array.length > 0
        ? Proc.run(
            ["conan", "lock", "bundle", "create", "--bundle-out=lock.bundle"]->Array.concat(locks),
          )->Task.map(output =>
            switch output {
            | Ok(_) => Ok(pkgInfos)
            | Error(e) => Error(e)
            }
          )
        : Ok(pkgInfos)->Task.resolve
    })
  })
  ->Flat.task
  ->Task.map(res => {
    res->Result.map(_ => {
      File.exists("lock.bundle")
        ? Proc.run([
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
        : res->Task.resolve
    })
  })
  ->Flat.task
  ->Task.map(res => {
    res->Result.flatMap(_ => {
      File.exists("build_order.json")
        ? File.read("build_order.json")->Result.map(content =>
            content->Js.Json.parseExn->toLockfile
          )
        : Ok([])
    })
  })
}

let getJob = (buildOrder, pkgInfos) => {
  buildOrder
  ->Array.mapWithIndex((index, group) => {
    group
    ->Array.map(pkg => {
      let revision = (pkg->Js.String2.split("#"))[1]
      let foundPkgs = pkgInfos->Js.Array2.filter(e => {
        switch revision {
        | Some(revision) => revision == e.info.revision
        | None => false
        }
      })
      foundPkgs
      ->Array.map(foundPkg => {
        let {int, profile, mode, hash} = foundPkg
        switch (
          (pkg->Js.String2.split("#"))[0],
          {int: int, profile: profile, mode: mode}->Detect.getImage,
        ) {
        | (Some(pkg), Ok(image)) =>
          Ok(
            (
              {
                name: `${pkg}${hash}`,
                script: {int: int, profile: profile, mode: mode}->getCmds,
                image: image,
                needs: switch int.req {
                | Some(needs) => needs
                | None => []
                }->Array.concat(
                  switch buildOrder[index - 1] {
                  | Some(group) => group
                  | None => []
                  },
                ),
              }: Job_t.t
            ),
          )
        | (_, Error(err)) => Error(err)
        | (None, _) => Error(`Invalid package: ${pkg}`)
        }
      })
      ->Array.concat([
        Ok({
          name: pkg,
          script: [],
          image: "",
          needs: foundPkgs->Array.map(foundPkg =>
            switch (pkg->Js.String2.split("#"))[0] {
            | Some(pkg) => `${pkg}${foundPkg.hash}`
            | _ => `Invalid package: ${pkg}`
            }
          ),
        }),
      ])
      ->Flat.array
    })
    ->Flat.array
    ->Result.map(Array.concatMany)
  })
  ->Flat.array
  ->Result.map(Array.concatMany)
}

let getJobs = (zips: array<Instance.zip>) => {
  let zips = zips->Js.Array2.filter(zip => zip.mode == #conan)
  let pkgInfos =
    zips
    ->conanInit
    ->Task.flatMap(exportPkgs =>
      switch exportPkgs {
      | Ok(_) => zips->Array.map(getInfo)->Task.all->Task.map(Flat.array)
      | Error(error) => Error(error)->Task.resolve
      }
    )
  let lockfile = pkgInfos->getLockFile
  Task.all2((pkgInfos, lockfile))->Task.map(((pkgInfos, lockfile)) => {
    switch (pkgInfos, lockfile) {
    | (Ok(pkgInfos), Ok(lockfile)) => lockfile->getJob(pkgInfos)
    | (Error(e), _) => Error(e)
    | (_, Error(e)) => Error(e)
    }
  })
}
