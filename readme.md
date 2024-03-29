# CICD
CICD tool for handling monorepos

## Arguments
You can specify the following arguments as environment variables to pipelines:
|Argument|Description|Default|Examples|
|-|-|-|-|
|mode|Mode to execute| "`manual`" (web trigger), "`git`" (push)| "`git`" / "`manual`"
|component|Components to build in manual mode| "" (empty string) | Build all versions of gst and gst-vaapi/1.20.0: "`gst/*,gst-vaapi/1.20.0`", Build all components except llvm: "`-llvm,*/*`",
|recursive|Search for components recursively in git submodules|true| Recursive: `true`, Non-recursive: "`false`", "`0`"

## Environment Variables being used
This repo relies on a few environment variables being available. Below is a list with no guarantees of completenes. Try searching for `Env.` in the repo

- DOCKER_USER               = username to log into the docker registry
- DOCKER_PASSWORD           = password for docker registry
- DOCKER_REGISTRY           = URL of registry
- DOCKER_PREFIX             = prefix to apply to docker containers. Usually refers to the gitlab repo associated. e.g. /aivero/open-source/contrib/
- DOCKER_DEPENDENCY_PROXY   = URL of gitlab dependency proxy to use. Note that this will re-use the above credentials to login
- DOCKER_DISTRO             = 
- CI_COMMIT_SHA             = ENV set by gitlab CICD: https://docs.gitlab.com/ee/ci/variables/predefined_variables.html
- CI_COMMIT_REF_NAME        = ENV set by gitlab CICD
- CI_COMMIT_BEFORE_SHA      = ENV set by gitlab CICD
- CONAN_DOCKER_REGISTRY     = URL of registry
- CONAN_CONFIG_URL          = Repo containing the Conan config
- CONAN_CONFIG_DIR          = Folder inside the Conan config's tarball generated by Gitlab, containing the conan config
- CONAN_LOGIN_USERNAME      = Username of conan registry  
- CONAN_LOGIN_PASSWORD      = Password for conan registry
- CONAN_REPO_INTERNAL       = URL of conan registry for proprietary packages
- CONAN_REPO_DEV_INTERNAL   = URL of conan registry for proprietary packages while being build by CICD
- CONAN_REPO_PUBLIC         = URL of conan registry for open-source packages
- CONAN_REPO_DEV_PUBLIC     = URL of conan registry for open-source packageswhile being build by CICD
- CONAN_DOCKER_PREFIX       = Prefix referring to open-source container registry on gitlab


## devops.yml example
### Base
Instance with explicit settings
```yaml
- name: pkg-name
  version: 0.2.7-hotfix
  folder: subfolder-with-runtime-content
  before_script:
   - echo init command
  script:
   - echo hello world
   - echo hello again
  after_script:
   - echo cleanup command
  image:
   - custom-docker-image 
  tags:
   - AWS
   - RASPBERRY_PI
```

Instance with all implicit settings
```yaml
- 
```
### Conan
Additional Conan settings
```yaml
 - profiles:
   - linux-x86_64
   - linux-armv8
   conan:
     settings:
       python: "3.8"
     options:
       x11: false
       wayland: true
```

### Docker
File setting
```yaml
- 
  name: image-name-1
  version: '0.0.1'
  docker:
    file: <path-to-docker-file1>.Dockerfile
- 
  name: image-name-2
  version: '0.0.1'
  docker:
    file: <path-to-docker-file2>.Dockerfile
```
Create docker instances from all files in current directory

The name will be set from the file

E.g `file-name.Dockerfile` will get the name `file-name`

```yaml
- version: '0.0.1'
```

## Development Commands
```
yarn # Install rescript

yarn dev # Development mode

yarn start # Start on current repo
```

### Run from workspace

```
cd contrib
cd ../workspace
CONAN_LOGIN_PASSWORD=YOUR_PW  CONAN_LOGIN_USERNAME=YOUR_USER component=dcd-docker DOCKER_USER=docker DOCKER_PASSWORD=docker_pw DOCKER_REGISTRY=https://registry.gitlab.com DOCKER_PREFIX=aivero/prop CONAN_REPO_DEV_PUBLIC=dev-public CONAN_REPO_PUBLIC=aivero-public CONAN_REPO_INTERNAL=aivero-internal CONAN_REPO_DEV_INTERNAL=dev-internal CONAN_CONFIG_DIR=conan-config-cicd CONAN_CONFIG_URL=https://gitlab.com/aivero/open-source/conan-config/-/archive/cicd/conan-config-cicd.tar.gz CI_COMMIT_SHA=3da80c4fa5341cb047d4faf7e0d7fc06661f3d14 CI_COMMIT_REF_NAME=master deno run --unstable --allow-all --import-map ../cicd/import_map.json ../cicd/lib/es6/src/GenerateConfig.js
```