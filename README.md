# GitHub Action: eic/run-cvmfs-osg-eic-shell
![linux](https://github.com/eic/run-cvmfs-osg-eic-shell/workflows/linux/badge.svg)![macOS](https://github.com/eic/run-cvmfs-osg-eic-shell/workflows/macOS/badge.svg)![dev](https://github.com/eic/run-cvmfs-osg-eic-shell/workflows/dev/badge.svg)

This GitHub Action executes user payload code inside a LCG view environment, specified by the user.

## Instructions

### Prerequisites
This action depends on the user to call the companion action `uses: cvmfs-contrib/github-action-cvmfs@v2` before using `uses: eic/run-cvmfs-osg-eic-shell@main`, which will install CVMFS on the node. GitHub Actions currently do not support calling the action `github-action-cvmfs` from within `run-lcg-view`, this needs to be done explicitly by the user.

### Example

You can use this GitHub Action in a workflow in your own repository with `uses: aidasoft/`.

A minimal job example for GitHub-hosted runners of type `ubuntu-latest`:
```yaml
jobs:
  run-lcg:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - uses: cvmfs-contrib/github-action-cvmfs@v2
    - uses: eic/run-cvmfs-osg-eic-shell@main
      with:
        release-platform: "LCG_99/x86_64-centos7-gcc10-opt"
        run: |
          gcc --version
          which gcc
```
In this case the action will automatically resolve the correct container image (in this case `centos7`) and spawn an instance with Docker from GitHub Container Registry or with Singularity from `/cvmfs/unpacked.cern.ch/`. The `Dockerfile` for the supported images can be found in the [AIDASoft/management](https://github.com/AIDASoft/management) repository.

The action mounts the checkout directory into the mentioned container and wraps the variable `run` in the script:

```sh
#!/usr/bin/env bash
export LC_ALL=C
set -e

source ${VIEW_PATH}/setup.sh

${RUN} # the multi-line variable specified in the action under run: |
```

which is executed in the container and thus giving the user an easy and direct access to run arbitrary code on top of LCG views.


The Action also works with runners of type `macos-latest`, however in this case it is necessary to specify the repositories you want to mount (via the variable `cvmfs_repositories`), as there is no auto mount for macOS. A minimal example of usage on `macos-latest` is:
```yaml
jobs:
  run-lcg:
    runs-on: macos-latest
    steps:
    - uses: actions/checkout@v2
    - uses: cvmfs-contrib/github-action-cvmfs@v2
      with:
        cvmfs_repositories: 'sft.cern.ch,geant4.cern.ch'
    - uses: eic/run-cvmfs-osg-eic-shell@main
      with:
        release-platform: "LCG_99/x86_64-mac1015-clang120-opt"
        run: |
          which ddsim
          ddsim --help
```
Beware that because the runner cannot be rebooted in the macOS case, the repositories are mounted under `/Users/Shared/cvmfs/`. It is also necessary to mount `geant4.cern.ch` in addition to `sft.cern.ch` as the Geant4 data files associated to a view are stored in the Geant4 cvmfs repository.

### Parameters
The following parameters are supported:
 - `container`: Which container to use as base to setup a view. By default the container is inferred from `view-path` (default: `auto`)
 - `platform`: LCG view platform you are targeting (e.g. `x86_64-centos8-gcc10-opt`)
 - `release`: LCG view release you are targeting (e.g. `LCG_99`)
 - `release-platform`:LCG view release platform string you are targeting (e.g. `LCG_99/x86_64-centos8-gcc10-opt`)
 - `unpacked`: Use image from `/cvmfs/unpacked.cern.ch` with Singularity, or if `false` use GitHub Container Registry with Docker (default: `false`)
 - `run`: They payload code you want to execute on top of the view
 - `setup-script`: Initialization/Setup script for a view that sets the environment (e.g. `setup.sh`)
 - `view-path`: Path where the setup script for the custom view is location. By specifying this variable the auto-resolving of the view based on `release` and `platform` is disabled. Furthermore the full path has to contain the architecture of the build in the form `/dir1/dir2/x86_64-{arch}-gcc../dir4/dir5`. The system will try to resolve the docker container equal to the string `{arch}` (the string after `x86_64-`).

Please be aware that you must use the combination of parameters `release` and `platform` together or use just the variable `release-platform` alone. These two options are given to enable more flexibility for the user to form their workflow with matrix expressions.

### Minimal Example

There are minimal examples, which are also workflows in this repository in the subfolder [.github/workflows/](https://github.com/eic/run-cvmfs-osg-eic-shell/tree/main/.github/workflows).

## Limitations

The action will always resolve the correct image to execute your code on top the requested view, therefore you must always set the top level GitHub Action variable `runs-on: ubuntu-latest`. However this is not the case if you want to execute on macOS, there you have to set this variable to `runs-on: macos-latest`.
