open Instance
open Job_t

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
  | Some(args) => args->Js.String2.split(" ")
  | None => []
  }

  let sets = switch int->Yaml.get("settings") {
  | Yaml.Object(sets) =>
    sets
    ->Js.Dict.entries
    ->Array.map(((key, val)) =>
      switch val {
      | Yaml.Bool(true) => (key, "True")
      | Yaml.Bool(false) => (key, "False")
      | _ => (key, "False")
      }
    )
  | _ => []
  }->Array.map(((key, val)) => `-s ${name}:${key}=${val}`)

  let opts = switch int->Yaml.get("options") {
  | Yaml.Object(opts) =>
    opts
    ->Js.Dict.entries
    ->Array.map(((key, val)) =>
      switch val {
      | Yaml.Bool(true) => (key, "True")
      | Yaml.Bool(false) => (key, "False")
      | _ => (key, "False")
      }
    )
  | _ => []
  }->Array.map(((key, val)) => `-o ${name}:${key}=${val}`)

  Flat.array([args, sets, opts])
}

let getRepo = folder => {
  [folder, "conanfile.py"]
  ->Path.join
  ->File.read
  ->Result.map(content =>
    content->Js.String2.includes("Proprietary") ? "$CONAN_REPO_INTERNAL" : "$CONAN_REPO_PUBLIC"
  )
}

let getVariables = ({base: {name, version, folder}, profile, args, repo}: conanInstance) => {
  [("NAME", name), ("VERSION", version), ("FOLDER", folder), ("REPO", repo), ("PROFILE", profile)]
  ->Array.concat(args->Array.length > 0 ? [("ARGS", args->Array.joinWith(" ", str => str))] : [])
  ->Array.concat(
    switch version->Js.String2.match_(%re("/^[0-9a-f]{40}$/")) {
    | Some(_) => [("UPLOAD_ALIAS", "1")]
    | _ => []
    },
  )
}

@send external toLockfile: 'a => array<array<string>> = "%identity"

let init = (ints: array<Instance.t>) => {
  let exportPkgs = ints->Js.Array2.reduce((pkgs, {name, version, folder}) => {
    pkgs->Array.some(pkg => pkg == (`${name}/${version}@`, folder))
      ? pkgs
      : pkgs->Array.concat([(`${name}/${version}@`, folder)])
  }, [])

  let config =
    switch (Env.get("CONAN_CONFIG_URL"), Env.get("CONAN_CONFIG_DIR"))->Seq.option2 {
    | Some(url, dir) => Ok((url, dir))
    | _ => Error("Conan config url or dir not defined")
    }
    ->Task.resolve
    ->TaskResult.flatMap(((url, dir)) => Proc.run(["conan", "config", "install", url, "-sf", dir]))

  config
  ->TaskResult.flatMap(_ =>
    switch [
      Env.get("CONAN_LOGIN_USERNAME"),
      Env.get("CONAN_LOGIN_PASSWORD"),
      Env.get("CONAN_REPO_ALL"),
    ]->Seq.option {
    | Some([user, passwd, repo]) => Proc.run(["conan", "user", user, "-p", passwd, "-r", repo])
    | _ => Error("Conan login, password or repo not defined")->Task.resolve
    }
  )
  ->TaskResult.flatMap(_ =>
    exportPkgs
    ->Array.map(((pkg, folder), ()) => {
      Proc.run(["conan", "export", folder, pkg])
    })
    ->TaskResult.pool(Sys.cpus)
  )
}

let getBuildOrder = (ints: array<conanInstance>) => {
  let locks = ints->Array.map(({base: {name, version}, hash}) => `${name}-${version}-${hash}.lock`)
  locks->Js.Console.log
  let bundle =
    locks->Array.length > 0
      ? Proc.run(
          ["conan", "lock", "bundle", "create", "--bundle-out=lock.bundle"]->Array.concat(locks),
        )
      : Ok("")->Task.resolve
  bundle
  ->TaskResult.flatMap(_ => {
    Proc.run(["conan", "lock", "bundle", "build-order", "lock.bundle", "--json=build_order.json"])
  })
  ->TaskResult.flatMap(_ => {
    File.read("build_order.json")
    ->Result.map(content => content->Js.Json.parseExn->toLockfile)
    ->Task.resolve
  })
}

let getExtends = ((profile, bootstrap)) => {
  let base = ".conan"

  let triple = profile->Js.String2.split("-")->List.fromArray

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
  ->Array.mapWithIndex((index, group) => {
    group
    ->Array.map(pkg => {
      let [pkg, pkgRevision] = pkg->Js.String2.split("#")
      let ints =
        ints->Js.Array2.filter(({base: {name, version}, revision}) =>
          pkgRevision == revision && pkg == `${name}/${version}@`
        )
      ints
      ->Array.map(int => {
        {
          name: `${int.base.name}/${int.base.version}@${int.hash}`,
          script: None,
          image: None,
          tags: None,
          variables: Some(int->getVariables->Js.Dict.fromArray),
          extends: Some(int.extends),
          needs: int.base.reqs->Array.concat(
            switch buildOrder[index - 1] {
            | Some(group) =>
              group->Array.map(pkg => {
                let [pkg, ver] = pkg->Js.String2.split("#")
                pkg ++ "#" ++ ver->String.sub(0, hashLength)
              })
            | None => []
            },
          ),
        }
      })
      ->Array.concat([
        {
          name: pkg ++ "#" ++ pkgRevision->String.sub(0, hashLength),
          script: Some(["echo"]),
          image: None,
          tags: Some(["x86_64"]),
          variables: None,
          extends: None,
          needs: ints->Array.map(foundPkg => `${pkg}${foundPkg.hash}`),
        },
      ])
    })
    ->Flat.array
  })
  ->Flat.array
}

let getConanInstances = (int: Instance.t) => {
  let {name, version, folder, modeInt} = int
  let repo = folder->getRepo
  let args = name->getArgs(modeInt)

  int.profiles->Js.Array2.map(profile => {
    let extends = (profile, int.bootstrap)->getExtends
    (extends, repo)
    ->Seq.result2
    ->Task.resolve
    ->TaskResult.flatMap(((extends, repo)) => {
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
      ->TaskResult.flatMap(_ => {
        File.read(`${name}-${version}-${hash}.lock`)
        ->Result.flatMap(lock =>
          switch lock
          ->Json.parse
          ->Json.get("graph_lock")
          ->Json.get("nodes")
          ->Json.get("1")
          ->Json.get("ref") {
          | Json.String(ref) =>
            switch (ref->Js.String2.split("#"))[1] {
            | Some(revision) => Ok(revision)
            | _ => Error(`Invalid lock file: ${name}-${version}-${hash}.lock`)
            }
          | _ => Error(`Invalid lock file: ${name}-${version}-${hash}.lock`)
          }
        )
        ->Task.resolve
      })
      ->TaskResult.flatMap(revision => {
        Ok({
          base: int,
          revision: revision,
          repo: repo,
          extends: extends,
          args: args,
          profile: profile,
          hash: hash,
        })->Task.resolve
      })
    })
  })
}

let getJobs = (ints: array<Instance.t>) => {
  let ints = ints->Js.Array2.filter(int => int.mode == #conan)
  ints
  ->init
  ->TaskResult.flatMap(_ => ints->Array.map(getConanInstances)->Flat.array->TaskResult.seq)
  ->TaskResult.flatMap(ints =>
    switch ints->Array.length {
    | 0 => Ok([])->Task.resolve
    | _ => ints->getBuildOrder->TaskResult.map(buildOrder => ints->getJob(buildOrder))
    }
  )
}
