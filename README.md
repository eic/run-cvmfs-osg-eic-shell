# GitHub Action: eic/run-cvmfs-osg-eic-shell
![linux](https://github.com/eic/run-cvmfs-osg-eic-shell/workflows/linux/badge.svg)

This GitHub Action executes user payload code inside a EIC shell environment, specified by the user.

## Instructions

### Prerequisites
This action depends on the user to call the companion action `uses: cvmfs-contrib/github-action-cvmfs@v4` before using `uses: eic/run-cvmfs-osg-eic-shell@v1`, which will install CVMFS on the node. GitHub Actions currently do not support calling the action `github-action-cvmfs` from within `run-cvmfs-osg-eic-shell`, this needs to be done explicitly by the user.

### Example

You can use this GitHub Action in a workflow in your own repository with `uses: eic/run-cvmfs-osg-eic-shell@v1`.

A minimal job example for GitHub-hosted runners of type `ubuntu-latest`:
```yaml
jobs:
  run-eic-shell:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - uses: cvmfs-contrib/github-action-cvmfs@v4
    - uses: eic/run-cvmfs-osg-eic-shell@v1
      with:
        platform-release: "eic_xl:nightly"
        run: |
          gcc --version
          which gcc
          eic-info
```
In this case the action will automatically resolve the correct container image (in this case `eic_xl:nightly`) and spawn an instance with Singularity from `/cvmfs/singularity.opensciencegrid.org/`.

The action mounts the checkout directory into the mentioned container and wraps the variable `run` in the script:

```sh
#!/usr/bin/env bash
export LC_ALL=C
set -Euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR
IFS=$'\n\t'
set -e

source ${SETUP}

${RUN} # the multi-line variable specified in the action under run: |
```

which is executed in the container and thus giving the user an easy and direct access to run arbitrary code on top of an EIC shell.


### Parameters
The following parameters are supported:
 - `platform`: EIC shell platform you are targeting (e.g. `eic_xl`)
 - `release`: EIC shell release you are targeting (e.g. `3.0-stable`)
 - `platform-release`: EIC shell platform release string you are targeting (e.g. `eic_xl:3.0-stable`)
 - `run`: They payload code you want to execute on top of the view
 - `setup`: Initialization/Setup script for a view that sets the environment (e.g. `/opt/detector/epic-main/bin/thisepic.sh`)
 - `sandbox-path`: Path where the setup script for the custom view is location. By specifying this variable the auto-resolving of the view based on `release` and `platform` is disabled.
 - `network_types`: Network types to setup inside container. Defaults to `bridge` networking, but can be `none` to disable networking.
 - `apptainer_version`: Apptainer version to use. Defaults to `latest`, but can be any version such as `v1.1.3`.

Please be aware that you must use the combination of parameters `release` and `platform` together or use just the variable `platform-release` alone. These two options are given to enable more flexibility for the user to form their workflow with matrix expressions.

### Minimal Example

There are minimal examples, which are also workflows in this repository in the subfolder [.github/workflows/](https://github.com/eic/run-cvmfs-osg-eic-shell/tree/main/.github/workflows).

## Limitations

The action will always resolve the correct image to execute your code on top the requested view, therefore you must always set the top level GitHub Action variable `runs-on: ubuntu-latest`.
