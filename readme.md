# CICD (WIP)
CICD tool for handling monorepos

## Arguments
You can specify the following arguments as environment variables to pipelines:
|Argument|Description|Default|Examples|
|-|-|-|-|
|mode|Mode to execute| `manual` (web trigger), `git` (push)| "`git`" / "`manual`"
|component|Components to build in manual mode| "" (empty string) | Build all versions of gst and gst-vaapi/1.20.0: "`gst/*,gst-vaapi/1.20.0`", Build all components except llvm: "`-llvm,*/*`",
|recursive|Search for components recursively in git submodules|true| Recursive: `true`, Non-recursive: "`false`", "`0`"

## Development Commands
```
yarn # Install rescript

yarn dev # Development mode

yarn start # Start on current repo
```