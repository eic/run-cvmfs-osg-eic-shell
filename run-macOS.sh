#!/bin/zsh

set -e
if [ -z "${SANDBOX_PATH}" ]; then
  echo "Checking if there is a working CVMFS mount"

  if [ ! -d "/Users/Shared/cvmfs/singularity.opensciencegrid.org/eicweb/" ]; then
    echo "The directory /Users/Shared/cvmfs/singularity.opensciencegrid.org/eicweb cannot be accessed!"
    echo "Make sure you are using the cvmfs-contrib/github-action-cvmfs@v2 action"
    echo "and that you have set cvmfs_repositories: 'singularity.opensciencegrid.org'."
    echo "There is no automount on macOS."
    exit 1
  fi

  echo "CVMFS mount present"

  SANDBOX_PATH="/Users/Shared/cvmfs/singularity.opensciencegrid.org/eicweb/${EIC_SHELL_PLATFORM_RELEASE}"
  if [[ "${EIC_SHELL_RELEASE}" == *"dev"* ]]; then
    SANDBOX_PATH="/Users/Shared/cvmfs/singularity.opensciencegrid.org/eicweb/${EIC_SHELL_PLATFORM}:${EIC_SHELL_RELEASE}"
  fi
fi

echo "Installing EIC shell prerequisites:"
brew install ninja
brew install gfortran
brew install --cask xquartz
echo "Installation done."

echo "Full EIC shell path is ${SANDBOX_PATH}"

if [ ! -d "${SANDBOX_PATH}" ]; then
  echo "Did not find an EIC shell under this path!"
  exit 1
fi

echo "#!/bin/zsh

set -e

cd ${GITHUB_WORKSPACE}

${RUN}
" > ${GITHUB_WORKSPACE}/action_payload.sh
chmod a+x ${GITHUB_WORKSPACE}/action_payload.sh

echo "####################################################################"
echo "###################### Executing user payload ######################"
echo "VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV"

cd ${GITHUB_WORKSPACE}
./action_payload.sh
