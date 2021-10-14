@send external toString: 'a => string = "toString"

let getArgs = (int: Instance.t) => {
  let args = switch Env.get("args") {
  | Some(args) => args->Js.String.split(" ", _)
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
    content->Js.String.includes("Proprietary", _) ? "$CONAN_REPO_INTERNAL" : "$CONAN_REPO_INTERNAL"
  )
}

let getCmds = ({int, profile}: Instance.pair): array<string> => {
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

type info = {
  revision: string,
  reference: string,
}

type infoTriple = {
  info: info,
  int: Instance.t,
  profile: string,
}

external toInfo: 'a => array<info> = "%identity"

let getInfo = ({int, profile}: Instance.pair) => {
  switch (int.name, int.version) {
  | (Some(name), Some(version)) =>
    Proc.run(
      Array.concatMany([
        ["conan", "info", "-j", `${name}-${version}-${profile}.json`, `-pr=${profile}`],
        int->getArgs,
        [`${name}/${version}@`],
      ]),
    )->Promise.thenResolve(_ => {
      switch File.read(`${name}-${version}-${profile}.json`) {
      | Ok(output) =>
        output
        ->Js.Json.parseExn
        ->toInfo
        ->Js.Array2.find(e => e.reference == `${name}/${version}`)
        ->(
          find =>
            switch find {
            | Some(info) => Some({int: int, profile: profile, info: info})
            | None => None
            }
        )

      //switch output
      //->(bla => { Js.Console.log(`start| |${output}| |end`); bla })
      //->Js.Json.parseExn
      //->toInfo
      //->Js.Array2.find(e => e.revision == `${name}/${version}`) {
      //| Some(info) => Some({int: int, profile: profile, info: info})
      //| None => None
      //}
      | Error(_) => None
      }
    })
  | _ => None->Promise.resolve
  }
}

let getLockFile = (triples: Js.Promise.t<array<option<infoTriple>>>) => {
  triples
  ->Promise.then(triple =>
    triple
    ->Array.map(triple => {
      let Some({int}) = triple
      switch (int.name, int.version, int.folder) {
      | (Some(name), Some(version), Some(folder)) =>
        Proc.run(["conan", "export", folder, `${name}/${version}@`])
      }->Promise.thenResolve(_ => triple)
    })
    ->Promise.all
  )
  ->Promise.then(triple => {
    triple
    ->Array.map(triple => {
      let {int, profile, info} = triple->Option.getExn
      switch (int.name, int.version, int.folder) {
      | (Some(name), Some(version), Some(folder)) =>
        Proc.run(
          [
            "conan",
            "lock",
            "create",
            `--ref=${name}/${version}`,
            `--lockfile-out=${name}-${version}-${info.revision}.lock`,
            `-pr=${profile}`,
          ]->Array.concat(int->getArgs),
        )
      }
    })
    ->Promise.all
    ->Promise.thenResolve(_ => triple)
  })
  ->Promise.then(triple => {
    let locks = triple->Array.map(triple => {
      let {int, profile, info} = triple->Option.getExn
      switch (int.name, int.version, int.folder) {
      | (Some(name), Some(version), Some(folder)) => `${name}-${version}-${info.revision}.lock`
      }
    })
    Proc.run(["conan", "lock", "bundle", "create", "--bundle-out=lock.bundle"]->Array.concat(locks))
  })
  ->Promise.then(_ => {
    Proc.run(["conan", "lock", "bundle", "build-order", "lock.bundle", "--json=build_order.json"])
  })
  ->Promise.thenResolve(_ => {
    File.read("build_order.json")
  })
}

let getJobs = (pair: array<Instance.pair>) => {
  let triples = pair->Array.map(getInfo)->Promise.all
  let lockfile = getLockFile(triples)
  let bla= lockfile->Task.map(Js.Console.log)
  let jobs = triples->Promise.thenResolve(triples =>
    triples->Array.map(triple => {
      switch triple {
      | Some(triple) =>
        switch {int: triple.int, profile: triple.profile}->Detect.getImage {
        | Ok(image) =>
          Ok(
            (
              {
                cmds: {int: triple.int, profile: triple.profile}->getCmds,
                image: image,
                needs: switch triple.int.needs {
                | Some(needs) => needs
                | None => []
                },
              }: Job_t.t
            ),
          )
        | Error(err) => Error(err)
        }
      }
    })
  )
  jobs
}
