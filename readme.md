# CICD
CICD tool for handling monorepos

## Arguments
You can specify the following arguments as environment variables to pipelines:
|Argument|Description|Default|Examples|
|-|-|-|-|
|mode|Mode to execute| "`manual`" (web trigger), "`git`" (push)| "`git`" / "`manual`"
|component|Components to build in manual mode| "" (empty string) | Build all versions of gst and gst-vaapi/1.20.0: "`gst/*,gst-vaapi/1.20.0`", Build all components except llvm: "`-llvm,*/*`",
|recursive|Search for components recursively in git submodules|true| Recursive: `true`, Non-recursive: "`false`", "`0`"

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