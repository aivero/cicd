open Instance
open Job_t

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

let hashLength = 3
let hashN = Hash.hashN(_, hashLength)

let getArgs = (int: Instance.t) => {
  let args = switch Env.get("args") {
  | Some(args) => args->Js.String2.split(" ")
  | None => []
  }

  let sets = switch Seq.option2(int.name, int.settings) {
  | Some(name, settings) =>
    settings
    ->Js.Dict.entries
    ->Array.map(((key, val)) => (
      key,
      val->toString == "true" ? "True" : val->toString == "false" ? "False" : val,
    ))
    ->Array.map(((key, val)) => `-s ${name}:${key}=${val}`)
  | _ => []
  }

  let opts = switch Seq.option2(int.name, int.options) {
  | Some(name, options) =>
    options
    ->Js.Dict.entries
    ->Array.map(((key, val)) => (
      key,
      val->toString == "true" ? "True" : val->toString == "false" ? "False" : val,
    ))
    ->Array.map(((key, val)) => `-o ${name}:${key}=${val}`)
  | _ => []
  }

  Flat.array([args, sets, opts])
}

let getRepo = (int: Instance.t) => {
  [int.folder->Option.getExn, "conanfile.py"]
  ->Path.join
  ->File.read
  ->Result.map(content =>
    content->Js.String2.includes("Proprietary") ? "$CONAN_REPO_INTERNAL" : "$CONAN_REPO_PUBLIC"
  )
}

let getVariables = ({int, profile}: Instance.zip) => {
  int
  ->getRepo
  ->Result.map(repo =>
    switch [int.name, int.version, int.folder]->Seq.option {
    | Some([name, version, folder]) =>
      [
        ("NAME", name),
        ("VERSION", version),
        ("FOLDER", folder),
        ("REPO", repo),
        ("PROFILE", profile),
      ]
      ->Array.concat(
        int->getArgs->Array.length > 0
          ? [("ARGS", int->getArgs->Array.joinWith(" ", str => str))]
          : [],
      )
      ->Array.concat(
        switch version->Js.String2.match_(%re("/^[0-9a-f]{40}$/")) {
        | Some(_) => [("UPLOAD_ALIAS", "1")]
        | _ => []
        },
      )
    | _ => []
    }
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
  let args = int->getArgs
  let cmds = switch ([int.name, int.version, int.folder]->Seq.option, repo) {
  | (Some([name, version, folder]), Ok(repo)) => {
      let createPkg = [
        ["conan", "create", "-u", folder, `${name}/${version}@`]
        ->Js.Array2.concat(args)
        ->Array.joinWith(" ", str => str),
      ]
      let createDbg = [
        ["conan", "create", folder, `${name}-dbg/${version}@`]
        ->Js.Array2.concat(args)
        ->Array.joinWith(" ", str => str),
      ]
      let uploadPkg = [
        ["conan", "upload", `${name}/${version}@`, "--all", "-c", "-r", repo]->Array.joinWith(
          " ",
          str => str,
        ),
      ]
      let uploadPkgAlias = switch Seq.option2(
        Env.get("CI_COMMIT_REF_NAME"),
        Js.String2.match_(version, %re("/^[0-9a-f]{40}$/")),
      ) {
      | Some(ref, _) => [
          ["conan", "upload", `${name}/${ref}@`, "--all", "-c", "-r", repo]->Array.joinWith(
            " ",
            str => str,
          ),
        ]
      | _ => []
      }
      let uploadDbg = switch int.debugPkg {
      | Some(true) => [
          [
            "conan",
            "upload",
            `${name}-dbg/${version}@`,
            "--all",
            "-c",
            "-r",
            repo,
          ]->Array.joinWith(" ", str => str),
        ]
      | _ => []
      }

      Flat.array([createPkg, createDbg, uploadPkg, uploadPkgAlias, uploadDbg])
    }
  | _ => []
  }

  Flat.array([initCmds, cmds])
}

external toConanInfo: 'a => array<conanInfo> = "%identity"

let getInfo = ({int, profile, mode}: Instance.zip) => {
  switch Seq.option2(int.name, int.version) {
  | Some(name, version) => {
      let hash = hashN({int: int, profile: profile, mode: mode})
      Proc.run(
        Flat.array([
          ["conan", "info", "-j", `${name}-${version}-${hash}.json`, `-pr=${profile}`],
          int->getArgs,
          [`${name}/${version}@`],
        ]),
      )->TaskResult.flatMap(_ =>
        File.read(`${name}-${version}-${hash}.json`)->Result.flatMap(output =>
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
        )
      )
    }
  | _ => Error("Name or version not defined")->Task.resolve
  }
}

@send external toLockfile: 'a => array<array<string>> = "%identity"

let init = (zips: array<Instance.zip>) => {
  let (url, dir) = switch Seq.option2(Env.get("CONAN_CONFIG_URL"), Env.get("CONAN_CONFIG_DIR")) {
  | Some(url, dir) => (url, dir)
  | _ => ("", "")
  }
  let config = Proc.run(["conan", "config", "install", url, "-sf", dir])
  let exportPkgs = zips->Js.Array2.reduce((a, zip) => {
    switch [zip.int.name, zip.int.version, zip.int.folder]->Seq.option {
    | Some([name, version, folder]) =>
      a->Array.some(e => e == (`${name}/${version}@`, folder))
        ? a
        : a->Array.concat([(`${name}/${version}@`, folder)])
    | _ => a
    }
  }, [])
  config
  ->Task.flatMap(_ => switch [Env.get("CONAN_LOGIN_USERNAME"), Env.get("CONAN_LOGIN_PASSWORD"), Env.get("CONAN_REPO_INTERNAL")]->Seq.option {
  | Some([user, passwd, repo]) => Proc.run(["conan", "user", user, "-p", passwd, "-r", repo])
  | _ => Ok("")->Task.resolve
  })
  ->TaskResult.map(_ =>
    exportPkgs
    ->Array.map(((pkg, folder), ()) => {
      Proc.run(["conan", "export", folder, pkg])
    })
    ->TaskResult.pool(Sys.cpus)
  )
  ->TaskResult.flatten
}

let getLockFile = (pkgInfos: Task.t<result<array<pkgInfo>, string>>) => {
  pkgInfos
  ->TaskResult.map(pkgInfos => {
    pkgInfos
    ->Array.map((pkgInfo, ()) => {
      switch Seq.option2(pkgInfo.int.name, pkgInfo.int.version) {
      | Some(name, version) =>
        Proc.run(
          [
            "conan",
            "lock",
            "create",
            `--ref=${name}/${version}`,
            `--build=${name}/${version}`,
            `--lockfile-out=${name}-${version}-${hashN(pkgInfo)}.lock`,
            `-pr=${pkgInfo.profile}`,
          ]->Array.concat(pkgInfo.int->getArgs),
        )->TaskResult.map(_ => pkgInfo)
      | _ => Error("This should not happen")->Task.resolve
      }
    })
    ->TaskResult.pool(Sys.cpus)
  })
  ->TaskResult.flatten
  ->TaskResult.map(pkgInfos => {
    let locks = pkgInfos->Array.map(pkgInfo => {
      switch Seq.option2(pkgInfo.int.name, pkgInfo.int.version) {
      | Some(name, version) => `${name}-${version}-${hashN(pkgInfo)}.lock`
      | _ => ""
      }
    })
    locks->Js.Console.log
    locks->Array.length > 0
      ? Proc.run(
          ["conan", "lock", "bundle", "create", "--bundle-out=lock.bundle"]->Array.concat(locks),
        )->TaskResult.map(_ => pkgInfos)
      : Ok(pkgInfos)->Task.resolve
  })
  ->TaskResult.flatten
  ->TaskResult.map(_ => {
    File.exists("lock.bundle")
      ? Proc.run([
          "conan",
          "lock",
          "bundle",
          "build-order",
          "lock.bundle",
          "--json=build_order.json",
        ])
      : Ok("")->Task.resolve
  })
  ->TaskResult.flatten
  ->TaskResult.flatMap(_ => {
    File.exists("build_order.json")
      ? File.read("build_order.json")->Result.map(content => content->Js.Json.parseExn->toLockfile)
      : Ok([])
  })
}

let getJob = (buildOrder, pkgInfos) => {
  buildOrder
  ->Array.mapWithIndex((index, group) => {
    group
    ->Array.map(pkg => {
      let [pkg, revision] = pkg->Js.String2.split("#")
      let foundPkgs =
        pkgInfos->Js.Array2.filter(e =>
          revision == e.info.revision && pkg == e.info.reference ++ "@"
        )
      foundPkgs
      ->Array.map(foundPkg => {
        let {int, profile, mode, hash} = foundPkg
        {int: int, profile: profile, mode: mode}
        ->Detect.getExtends
        ->Result.flatMap(extends => {
          {int: int, profile: profile, mode: mode}
          ->getVariables
          ->Result.map(variables => {
            name: `${int.name->Option.getExn}/${int.version->Option.getExn}@${hash}`,
            script: None,
            image: None,
            tags: None,
            variables: Some(variables->Js.Dict.fromArray),
            extends: Some(extends),
            needs: switch int.req {
            | Some(needs) => needs
            | None => []
            }->Array.concat(
              switch buildOrder[index - 1] {
              | Some(group) =>
                group->Array.map(pkg => {
                  let [pkg, ver] = pkg->Js.String2.split("#")
                  pkg ++ "#" ++ ver->String.sub(0, hashLength)
                })
              | None => []
              },
            ),
          })
        })
      })
      ->Array.concat([
        Ok({
          name: pkg ++ "#" ++ revision->String.sub(0, hashLength),
          script: Some(["echo"]),
          image: None,
          tags: Some(["x86_64"]),
          variables: None,
          extends: None,
          needs: foundPkgs->Array.map(foundPkg => `${pkg}${foundPkg.hash}`),
        }),
      ])
      ->Seq.result
    })
    ->Seq.result
    ->Result.map(Flat.array)
  })
  ->Seq.result
  ->Result.map(Flat.array)
}

let getJobs = (zips: array<Instance.zip>) => {
  let zips = zips->Js.Array2.filter(zip => zip.mode == #conan)
  let pkgInfos =
    zips
    ->init
    ->TaskResult.map(_ => zips->Array.map((zip, ()) => zip->getInfo)->TaskResult.pool(Sys.cpus))
    ->TaskResult.flatten
  let lockfile = pkgInfos->getLockFile
  Task.all2((pkgInfos, lockfile))->Task.map(((pkgInfos, lockfile)) => {
    switch (pkgInfos, lockfile) {
    | (Ok(pkgInfos), Ok(lockfile)) => lockfile->getJob(pkgInfos)
    | (Error(e), _) => Error(e)
    | (_, Error(e)) => Error(e)
    }
  })
}
