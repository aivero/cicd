open Instance
open! Jobt

type conanInstance = {
  base: Instance.t,
  extends: array<string>,
  hash: string,
  revision: string,
  profile: string,
  repo: string,
  args: array<string>,
}

type conanInfo = {
  revision: string,
  reference: string,
}

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

  [args, sets, opts]->Array.flatten
}

let getRepo = folder => {
  [folder, "conanfile.py"]
  ->Path.join
  ->File.read
  ->Result.map(content =>
    content->String.includes("Proprietary") ? "$CONAN_REPO_INTERNAL" : "$CONAN_REPO_PUBLIC"
  )
}

let getVariables = ({base: {name, version, folder}, profile, args, repo}: conanInstance) => {
  [("NAME", name), ("VERSION", version), ("FOLDER", folder), ("REPO", repo), ("PROFILE", profile)]
  ->Array.concat(args->Array.empty ? [] : [("ARGS", args->Array.join(" "))])
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
  ->Task.flatMap(_ =>
    ("CONAN_LOGIN_USERNAME", "CONAN_LOGIN_PASSWORD", "CONAN_REPO_ALL")
    ->Tuple.map3(Env.getError)
    ->Result.seq3
    ->Task.fromResult
    ->Task.map(((user, passwd, repo)) =>
      Proc.run(["conan", "user", user, "-p", passwd, "-r", repo])
    )
  )
  ->Task.flatMap(_ =>
    exportPkgs
    ->Array.map(((pkg, folder), ()) => {
      Proc.run(["conan", "export", folder, pkg])
    })
    ->Task.pool(Sys.cpus)
  )
}

let getBuildOrder = (ints: array<conanInstance>) => {
  let locks = ints->Array.map(({base: {name, version}, hash}) => `${name}-${version}-${hash}.lock`)
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

let getJob = (ints: array<conanInstance>, buildOrder) => {
  buildOrder
  ->Array.flatMapWithIndex((index, group) => {
    group->Array.flatMap(pkg => {
      let (pkg, pkgRevision) = switch pkg->String.split("@#") {
      | [pkg, pkgRevision] => (pkg, pkgRevision)
      | _ => ("invalid-pkg", "invalid-rev")
      }
      let ints =
        ints->Array.filter(({base: {name, version}, revision}) =>
          pkgRevision == revision && pkg == `${name}/${version}`
        )
      ints
      ->Array.map(int => {
        Dict.to(
          `${int.base.name}/${int.base.version}@${int.hash}`,
          {
            script: None,
            image: None,
            services: None,
            tags: None,
            variables: Some(int->getVariables),
            extends: Some(int.extends),
            needs: int.base.needs
            ->Array.concat(
              switch buildOrder[index - 1] {
              | Some(group) =>
                group->Array.map(pkg => {
                  switch pkg->String.split("@#") {
                  | [pkg, _] => pkg
                  | _ => "invalid-pkg"
                  }
                })
              | None => []
              },
            )
            ->Array.uniq,
            cache: None,
          },
        )
      })
      ->Array.concat([
        Dict.to(
          pkg,
          {
            script: Some(["echo"]),
            image: None,
            services: None,
            tags: Some(["x86_64"]),
            variables: None,
            extends: None,
            needs: ints->Array.map(foundPkg => `${pkg}@${foundPkg.hash}`),
            cache: None,
          },
        ),
      ])
    })
  })
  ->Array.concat([
    Dict.to(
      "conan-upload",
      {
        script: {
          [
            "conan config install $CONAN_CONFIG_URL -sf $CONAN_CONFIG_DIR",
            "conan config set storage.path=$CONAN_DATA_PATH",
            "conan user $CONAN_LOGIN_USERNAME -p $CONAN_LOGIN_PASSWORD -r $CONAN_REPO_ALL",
            "conan user $CONAN_LOGIN_USERNAME -p $CONAN_LOGIN_PASSWORD -r $CONAN_REPO_INTERNAL",
            "conan user $CONAN_LOGIN_USERNAME -p $CONAN_LOGIN_PASSWORD -r $CONAN_REPO_PUBLIC",
          ]
          ->Array.concat(
            buildOrder
            ->Array.flatten
            ->Array.map(pkg => {
              switch pkg->String.split("@#") {
              | [pkg, _] =>
                switch (
                  pkg->String.split("/"),
                  ints->Array.find(({base: {name, version}}) =>
                    pkg->String.startsWith(`${name}/${version}`)
                  ),
                ) {
                | ([name, version], Some(int)) => (name, version, int.repo)
                | _ => ("invalid-name", "invalid-version", "")
                }
              | _ => ("invalid-name", "invalid-version", "")
              }
            })
            ->Array.flatMap(((name, version, repo)) => {
              [`conan upload ${name}/${version}@ --all -c -r ${repo}`]->Array.concat(
                switch version->String.match(%re("/^[0-9a-f]{40}$/")) {
                | Some(_) => [`conan upload ${name}/$CI_COMMIT_REF_NAME@ --all -c -r ${repo}`]
                | _ => []
                },
              )
            }),
          )
          ->Some
        },
        image: Some(
          "registry.gitlab.com/aivero/open-source/contrib/focal-x86_64-dockerfile:master",
        ),
        services: None,
        tags: Some(["x86_64", "aws"]),
        variables: Some(
          Dict.fromArray([
            ("CONAN_DATA_PATH", "$CI_PROJECT_DIR/conan_data"),
            ("GIT_CLEAN_FLAGS", "-x -f -e $CONAN_DATA_PATH/**"),
          ]),
        ),
        extends: None,
        needs: switch buildOrder[buildOrder->Array.length - 1] {
        | Some(needs) =>
          needs->Array.map(need =>
            switch need->String.split("@#") {
            | [need, _] => need
            | _ => "invalid_need"
            }
          )
        | None => []
        },
        cache: Some({
          key: Some("$CI_PIPELINE_ID"),
          paths: ["$CONAN_DATA_PATH"],
        }),
      },
    ),
  ])
}

let getConanInstances = (int: Instance.t) => {
  let {name, version, folder, modeInt} = int
  let repo = folder->getRepo
  let args = name->getArgs(modeInt)

  int.profiles
  ->Array.map(profile => {
    let extends = (profile, int.bootstrap)->getExtends
    (extends, repo)
    ->Result.seq2
    ->Task.fromResult
    ->Task.flatMap(((extends, repo)) => {
      let hash = {
        base: int,
        repo: repo,
        args: args,
        extends: extends,
        profile: profile,
        revision: "",
        hash: "",
      }->hashN
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
          extends: extends,
          args: args,
          profile: profile,
          hash: hash,
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
    ints
    ->Array.map((int, ()) => int->getConanInstances)
    ->Task.pool(Sys.cpus)
    ->Task.map(Array.flatten)
  )
  ->Task.flatMap(ints =>
    ints->Array.empty
      ? []->Task.to
      : ints->getBuildOrder->Task.map(buildOrder => ints->getJob(buildOrder))
  )
}
