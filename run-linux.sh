#!/usr/bin/env bash

set -e

echo "Checking if there is a working CVMFS mount"

if [ ! -d "/cvmfs/singularity.opensciencegrid.org" ]; then
  echo "The directory /cvmfs/singularity.opensciencegrid.org cannot be accessed!"
  echo "Make sure you are using the cvmfs-contrib/github-action-cvmfs@v2 action"
  exit 1
fi

echo "CVMFS mount present"

if [ -z "${SANDBOX_PATH}" ]; then
  SANDBOX_PATH="/cvmfs/singularity.opensciencegrid.org/eicweb/${EIC_SHELL_PLATFORM_RELEASE}"
  if [[ "${EIC_SHELL_RELEASE}" == *"dev"* ]]; then
    SANDBOX_PATH="/cvmfs/singularity.opensciencegrid.org/eicweb/${EIC_SHELL_PLATFORM}:${EIC_SHELL_RELEASE}"
  fi
fi

echo "Full EIC shell path is ${SANDBOX_PATH}"

if [ ! -d "${SANDBOX_PATH}" ]; then
  echo "Did not find an EIC shell under this path!"
  exit 1
fi

echo "#!/usr/bin/env bash
export LC_ALL=C
set -Euo pipefail
trap 's=\$?; echo \"\$0: Error on line \"\$LINENO\": \$BASH_COMMAND\"; exit \$s' ERR
IFS=\$'\n\t'
set -e

${SETUP:+source ${SETUP}}

${RUN}
" > ${GITHUB_WORKSPACE}/action_payload.sh
chmod a+x ${GITHUB_WORKSPACE}/action_payload.sh

echo "Install Singularity"
conda install --quiet --yes -c conda-forge singularity > /dev/null 2>&1
eval "$(conda shell.bash hook)"

worker=$(echo ${SANDBOX_PATH} | sha256sum | awk '{print$1}')
if singularity instance list | grep ${worker} ; then
  echo "Reusing exisitng Singularity image from ${SANDBOX_PATH}"
 else
  echo "Starting Singularity image from ${SANDBOX_PATH}"
  singularity instance start --bind /cvmfs --bind ${GITHUB_WORKSPACE}:${GITHUB_WORKSPACE} --network ${NETWORK_TYPES:-bridge} ${SANDBOX_PATH} ${worker}
fi

echo "####################################################################"
echo "###################### Executing user payload ######################"
echo "VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV"

singularity exec instance://${worker} /bin/bash -c "cd ${GITHUB_WORKSPACE}; ./action_payload.sh"
