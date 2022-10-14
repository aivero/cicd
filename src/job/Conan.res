open Instance
open! Jobt

type conanInstance = {
  base: Instance.t,
  extends: array<string>,
  revision: string,
  profile: string,
  repo: string,
  repoDev: string,
  args: array<string>,
}

type conanInfo = {
  revision: string,
  reference: string,
}

let extends = [
  (
    ".git-strat-none",
    {
      ...Jobt.default,
      variables: Some(
        [
          ("GIT_STRATEGY", "none"),
        ]->Dict.fromArray,
      ),
    },
  ),
  (
    ".conan",
    {
      ...Jobt.default,
      variables: Some(
        [
          ("CONAN_USER_HOME", "$CI_PROJECT_DIR"),
          ("CONAN_DATA_PATH", "$CI_PROJECT_DIR/conan_data"),
          ("GIT_SUBMODULE_STRATEGY", "recursive"),
          ("CARGO_HOME", "$CI_PROJECT_DIR/.cargo"),
          ("SCCACHE_DIR", "$CI_PROJECT_DIR/.sccache"),
          ("GIT_CLEAN_FLAGS", "-x -f -e $CARGO_HOME/** -e $SCCACHE_DIR/**"),
        ]->Dict.fromArray,
      ),
      script: Some([
        "conan config install $CONAN_CONFIG_URL -sf $CONAN_CONFIG_DIR",
        "conan config set general.default_profile=$PROFILE",
        "conan config set storage.path=$CONAN_DATA_PATH",
        "conan user $CONAN_LOGIN_USERNAME -p $CONAN_LOGIN_PASSWORD -r $CONAN_REPO_ALL",
        "conan user $CONAN_LOGIN_USERNAME -p $CONAN_LOGIN_PASSWORD -r $CONAN_REPO_DEV_ALL",
        "conan user $CONAN_LOGIN_USERNAME -p $CONAN_LOGIN_PASSWORD -r $CONAN_REPO_DEV_INTERNAL",
        "conan user $CONAN_LOGIN_USERNAME -p $CONAN_LOGIN_PASSWORD -r $CONAN_REPO_DEV_PUBLIC",
        "conan create -u . $NAME/$VERSION@ $ARGS",
        "conan user $CONAN_LOGIN_USERNAME -p $CONAN_LOGIN_PASSWORD -r $REPO",
        "conan upload $NAME/$VERSION@ --all -c -r $REPO",
        "[[ -n $UPLOAD_ALIAS ]] && conan upload $NAME/$CI_COMMIT_REF_NAME@ --all -c -r $REPO || echo",
      ]),
      cache: Some({
        key: Some("$CI_RUNNER_EXECUTABLE_ARCH"),
        paths: ["$CARGO_HOME", "$SCCACHE_DIR"],
      }),
      retry: Some({
        max: Some(2),
        \"when": Some(["runner_system_failure", "stuck_or_timeout_failure"]),
      }),
      artifacts: Some({
        expire_in: Some("1 month"),
        \"when": Some("always"),
        paths: Some([
          "conan_data/$NAME/$VERSION/_/_/build/*/meson-logs/*-log.txt",
          "conan_data/$NAME/$VERSION/_/_/build/*/*/meson-logs/*-log.txt",
          "conan_data/$NAME/$VERSION/_/_/build/*/CMakeFiles/CMake*.log",
          "conan_data/$NAME/$VERSION/_/_/build/*/*/CMakeFiles/CMake*.log",
          "conan_data/$NAME/$VERSION/_/_/build/*/*/config.log",
        ]),
      }),
    },
  ),
  (
    ".conan-x86_64",
    {
      ...Jobt.default,
      extends: Some([".conan"]),
      tags: "linux-x86_64"->Profile.getTags->Result.toOption,
      image: "linux-x86_64"
      ->Profile.getImage(Env.get("CONAN_DOCKER_REGISTRY"), Env.get("CONAN_DOCKER_PREFIX"))
      ->Result.toOption,
    },
  ),
  (
    ".conan-armv8",
    {
      ...Jobt.default,
      extends: Some([".conan"]),
      tags: "linux-armv8"->Profile.getTags->Result.toOption,
      image: "linux-armv8"
      ->Profile.getImage(Env.get("CONAN_DOCKER_REGISTRY"), Env.get("CONAN_DOCKER_PREFIX"))
      ->Result.toOption,
    },
  ),
  (
    ".conan-x86_64-bootstrap",
    {
      ...Jobt.default,
      extends: Some([".conan-x86_64"]),
      image: "linux-x86_64"
      ->Profile.getImage(Env.get("CONAN_DOCKER_REGISTRY"), Env.get("CONAN_DOCKER_PREFIX"))
      ->Result.toOption
      ->Option.map(image => image ++ "-bootstrap"),
    },
  ),
  (
    ".conan-armv8-bootstrap",
    {
      ...Jobt.default,
      extends: Some([".conan-armv8"]),
      image: "linux-armv8"
      ->Profile.getImage(Env.get("CONAN_DOCKER_REGISTRY"), Env.get("CONAN_DOCKER_PREFIX"))
      ->Result.toOption
      ->Option.map(image => image ++ "-bootstrap"),
    },
  ),
]

let hashLength = 3
let hashN = Hash.hashN(_, hashLength)

let getArgs = (name, int: Yaml.t) => {
  let args = switch Env.get("args") {
  | Some(args) => args->String.split(" ")
  | None => []
  }

  let sets =
    switch int->Yaml.get("settings") {
    | Yaml.Object(sets) =>
      sets->Dict.map(((key, val)) =>
        switch val {
        | Yaml.Bool(true) => (key, "True")
        | Yaml.Bool(false) => (key, "False")
        | _ => (key, "False")
        }
      )
    | _ => Dict.empty()
    }
    ->Dict.toArray
    ->Array.map(((key, val)) => `-s ${name}:${key}=${val}`)

  let opts =
    switch int->Yaml.get("options") {
    | Yaml.Object(opts) =>
      opts->Dict.map(((key, val)) =>
        switch val {
        | Yaml.Bool(true) => (key, "True")
        | Yaml.Bool(false) => (key, "False")
        | _ => (key, "False")
        }
      )
    | _ => Dict.empty()
    }
    ->Dict.toArray
    ->Array.map(((key, val)) => `-o ${name}:${key}=${val}`)

  [args, sets, opts]->Array.flat
}

let getRepos = folder => {
  [folder, "conanfile.py"]
  ->Path.join
  ->File.read
  ->Result.map(content =>
    content->String.includes("Proprietary")
      ? ("$CONAN_REPO_INTERNAL", "$CONAN_REPO_DEV_INTERNAL")
      : ("$CONAN_REPO_PUBLIC", "$CONAN_REPO_DEV_PUBLIC")
  )
}

let getVariables = ({base: {name, version}, profile, args, repoDev}: conanInstance) => {
  [("NAME", name), ("VERSION", version), ("REPO", repoDev), ("PROFILE", profile)]
  ->Array.concat(args->Array.empty ? [] : [("ARGS", args->Array.join(" "))])
  ->Array.concat(
    switch version->String.match(%re("/^[0-9a-f]{40}$/")) {
    | Some(_) => [("UPLOAD_ALIAS", "1")]
    | _ => []
    },
  )
  ->Dict.fromArray
}

let init = (ints: array<Instance.t>) => {
  let exportPkgs = ints->Array.reduce((pkgs, {name, version, folder}) => {
    pkgs->Array.some(pkg => pkg == (`${name}/${version}@`, folder))
      ? pkgs
      : pkgs->Array.concat([(`${name}/${version}@`, folder)])
  }, [])

  let config =
    ("CONAN_CONFIG_URL", "CONAN_CONFIG_DIR")
    ->Tuple.map2(Env.getError)
    ->Result.seq2
    ->Task.fromResult
    ->Task.flatMap(((url, dir)) => Proc.run(["conan", "config", "install", url, "-sf", dir]))

  config
  ->Task.flatMap(_ => {
    ("CONAN_LOGIN_USERNAME", "CONAN_LOGIN_PASSWORD")
    ->Tuple.map2(Env.getError)
    ->Result.seq2
    ->Task.fromResult
    ->Task.flatMap(((user, passwd)) => {
      [
        "CONAN_REPO_INTERNAL",
        "CONAN_REPO_DEV_INTERNAL",
        "CONAN_REPO_PUBLIC",
        "CONAN_REPO_DEV_PUBLIC",
      ]
      ->Array.map(Env.getError)
      ->Result.seq
      ->Task.fromResult
      ->Task.flatMap(res =>
        res
        ->Array.map(repo => Proc.run(["conan", "user", user, "-p", passwd, "-r", repo]))
        ->Task.seq
      )
    })
  })
  ->Task.flatMap(_ =>
    exportPkgs
    ->Array.map(((pkg, folder), ()) => {
      Proc.run(["conan", "export", folder, pkg])
    })
    ->Task.pool(Sys.cpus)
  )
}

let getBuildOrder = (ints: array<conanInstance>) => {
  let locks =
    ints->Array.map(({base: {name, version}} as int) =>
      `${name}-${version}-${(int.base, int.profile)->hashN}.lock`
    )
  let bundle =
    locks->Array.empty
      ? ""->Task.to
      : Proc.run(
          ["conan", "lock", "bundle", "create", "--bundle-out=lock.bundle"]->Array.concat(locks),
        )
  bundle
  ->Task.flatMap(_ => {
    Proc.run(["conan", "lock", "bundle", "build-order", "lock.bundle", "--json=build_order.json"])
  })
  ->Task.flatMap(_ => {
    File.read("build_order.json")
    ->Result.map(content => {
      content
      ->Json.parse
      ->Json.Array.get
      ->Array.map(array => array->Json.Array.get->Array.map(Json.String.get))
    })
    ->Task.fromResult
  })
}

let getExtends = ((profile, bootstrap)) => {
  let base = ".conan"

  let triple = profile->String.split("-")->List.fromArray

  let arch = switch triple {
  | list{_, "x86_64", ..._} | list{_, "wasm", ..._} => Ok("x86_64")
  | list{_, "armv8", ..._} => Ok("armv8")
  | _ => Error(`Could not detect image arch for profile: ${profile}`)
  }

  let end = bootstrap ? "-bootstrap" : ""

  arch->Result.map(arch => [`${base}-${arch}${end}`])
}

let getJob = (allInts: array<conanInstance>, buildOrder) => {
  buildOrder
  ->Array.flatMapWithIndex((index, group) => {
    let groupJobName = `group-job-${index->Int.toString}`
    let groupJobNeeds = switch buildOrder[index - 1] {
    | Some(group) =>
      group->Array.flatMap(pkg => {
        switch pkg->String.split("@#") {
        | [pkg, _] =>
          allInts->Array.some(({base}) => `${base.name}/${base.version}` == pkg) ? [pkg] : []
        | _ => []
        }
      })
    | None => []
    }->Array.uniq

    let groupJob = (
      groupJobName,
      {
        ...Jobt.default,
        script: Some(["echo"]),
        tags: Some(["x86_64"]),
        needs: Some(groupJobNeeds),
      },
    )

    // Only add group job to output if it actually has any needs. If it does not, then it doesn't
    // do anything and we are just waisting time trying to run it.
    let groupJobInOutPut = switch groupJobNeeds->Array.length {
    | 0 => []
    | _ => [groupJob]
    }
    let groupJobNeededInOutPut = switch groupJobNeeds->Array.length {
    | 0 => []
    | _ => [groupJobName]
    }

    group
    ->Array.flatMap(pkg => {
      let (pkg, pkgRevision) = switch pkg->String.split("@#") {
      | [pkg, pkgRevision] => (pkg, pkgRevision)
      | _ => ("invalid-pkg", "invalid-rev")
      }
      let ints =
        allInts->Array.filter(({base: {name, version}, revision}) =>
          pkgRevision == revision && pkg == `${name}/${version}`
        )
      ints->Array.map(({base, profile, extends} as int) => {
        `Found conan instance: ${base.name}/${base.version} (${profile})`->Console.log
        let image = switch int.base.image {
        | Some(image) => {
            Console.log("Conan Mode: Image is set, using it as docker image")
            Some(image)
          }
        | _ => {
            Console.log("Conan Mode: Image is not set, using default")
            None
          }
        }
        (
          `${base.name}/${base.version}`,
          {
            ...Jobt.default,
            variables: Some(int->getVariables),
            extends: Some(extends),
            image: image,
            before_script: Some(
              [`cd $CI_PROJECT_DIR/${int.base.folder}`]->Array.concat(int.base.beforeScript),
            ),
            after_script: Some(
              [`cd $CI_PROJECT_DIR/${int.base.folder}`]->Array.concat(int.base.afterScript),
            ),
            needs: Some(base.needs->Array.concat(groupJobNeededInOutPut)->Array.uniq),
          },
        )
      })
    })
    ->Array.concat(groupJobInOutPut)
  })
  ->Array.concat([
    (
      "conan-upload",
      {
        ...Jobt.default,
        extends: Some([".git-strat-none"]),
        script: Some(
          [
            "conan config install $CONAN_CONFIG_URL -sf $CONAN_CONFIG_DIR",
            "conan config set storage.path=$CONAN_DATA_PATH",
            "conan user $CONAN_LOGIN_USERNAME -p $CONAN_LOGIN_PASSWORD -r $CONAN_REPO_INTERNAL",
            "conan user $CONAN_LOGIN_USERNAME -p $CONAN_LOGIN_PASSWORD -r $CONAN_REPO_PUBLIC",
            "conan user $CONAN_LOGIN_USERNAME -p $CONAN_LOGIN_PASSWORD -r $CONAN_REPO_DEV_INTERNAL",
            "conan user $CONAN_LOGIN_USERNAME -p $CONAN_LOGIN_PASSWORD -r $CONAN_REPO_DEV_PUBLIC",
          ]->Array.concat(
            buildOrder
            ->Array.flat
            ->Array.reduce((pkgs, pkg) => {
              switch pkg->String.split("@#") {
              | [pkg, _] =>
                switch (
                  pkg->String.split("/"),
                  allInts->Array.find(({base: {name, version}}) =>
                    pkg->String.startsWith(`${name}/${version}`)
                  ),
                ) {
                | ([name, version], Some(int)) =>
                  pkgs->Array.concat([(name, version, int.repo, int.repoDev)])
                | _ => pkgs
                }
              | _ => pkgs
              }
            }, [])
            ->Array.flatMap(((name, version, repo, repoDev)) => {
              [
                `conan download ${name}/${version}@ -r ${repoDev}`,
                `conan upload ${name}/${version}@ --all -c -r ${repo}`,
              ]->Array.concat(
                switch version->String.match(%re("/^[0-9a-f]{40}$/")) {
                | Some(_) => [
                    `conan download ${name}/$CI_COMMIT_REF_NAME@ -r ${repoDev}`,
                    `conan upload ${name}/$CI_COMMIT_REF_NAME@ --all -c -r ${repo}`,
                  ]
                | _ => []
                },
              )
            }),
          ),
        ),
        image: Profile.default
        ->Profile.getImage(Env.get("CONAN_DOCKER_REGISTRY"), Env.get("CONAN_DOCKER_PREFIX"))
        ->Result.toOption,
        tags: Profile.default->Profile.getTags->Result.toOption,
        needs: switch buildOrder[buildOrder->Array.length - 1] {
        | Some(needs) =>
          Some(
            needs->Array.map(need =>
              switch need->String.split("@#") {
              | [need, _] => need
              | _ => "invalid-need"
              }
            ),
          )
        | None => Some([])
        },
      },
    ),
  ])
}

let getConanInstances = (int: Instance.t) => {
  let {name, version, folder, modeInt} = int
  let repos = folder->getRepos
  let args = name->getArgs(modeInt)

  int.profiles
  ->Array.map(profile => {
    let extends = (profile, int.bootstrap)->getExtends
    (extends, repos)
    ->Result.seq2
    ->Task.fromResult
    ->Task.flatMap(((extends, (repo, repoDev))) => {
      let hash = (int, profile)->hashN
      Proc.run(
        [
          "conan",
          "lock",
          "create",
          `--ref=${name}/${version}`,
          `--build=${name}/${version}`,
          `--lockfile-out=${name}-${version}-${hash}.lock`,
          `-pr=${profile}`,
        ]->Array.concat(args),
      )
      ->Task.flatMap(_ => {
        File.read(`${name}-${version}-${hash}.lock`)
        ->Result.flatMap(lock =>
          switch lock
          ->Json.parse
          ->Json.Object.get("graph_lock")
          ->Json.Object.get("nodes")
          ->Json.Object.get("1")
          ->Json.Object.get("ref") {
          | Json.String(ref) =>
            switch (ref->String.split("#"))[1] {
            | Some(revision) => Ok(revision)
            | _ => Error(`Invalid lock file: ${name}-${version}-${hash}.lock`)
            }
          | _ => Error(`Invalid lock file: ${name}-${version}-${hash}.lock`)
          }
        )
        ->Task.fromResult
      })
      ->Task.flatMap(revision => {
        {
          base: int,
          revision: revision,
          repo: repo,
          repoDev: repoDev,
          extends: extends,
          args: args,
          profile: profile,
        }->Task.to
      })
    })
  })
  ->Task.seq
}

let getJobs = (ints: array<Instance.t>) => {
  let ints = ints->Array.filter(int => int.mode == #conan)
  ints
  ->init
  ->Task.flatMap(_ =>
    ints->Array.map((int, ()) => int->getConanInstances)->Task.pool(Sys.cpus)->Task.map(Array.flat)
  )
  ->Task.flatMap(ints =>
    ints->Array.empty
      ? []->Task.to
      : ints
        ->getBuildOrder
        ->Task.map(buildOrder => ints->getJob(buildOrder))
        ->Task.map(jobs => extends->Array.concat(jobs))
  )
}
