#!/usr/bin/env bash

set -e

echo "::group::Checking if there is a working CVMFS mount"

if [ ! -d "/cvmfs/singularity.opensciencegrid.org" ]; then
  echo "The directory /cvmfs/singularity.opensciencegrid.org cannot be accessed!"
  echo "Make sure you are using the cvmfs-contrib/github-action-cvmfs@v2 action"
  exit 1
fi

echo "CVMFS mount present"
echo "::endgroup::"

if [ -z "${SANDBOX_PATH}" ]; then
  SANDBOX_PATH="/cvmfs/singularity.opensciencegrid.org/${EIC_SHELL_ORGANIZATION}/${EIC_SHELL_PLATFORM_RELEASE}"
  if [[ "${EIC_SHELL_RELEASE}" == *"dev"* ]]; then
    SANDBOX_PATH="/cvmfs/singularity.opensciencegrid.org/${EIC_SHELL_ORGANIZATION}/${EIC_SHELL_PLATFORM}:${EIC_SHELL_RELEASE}"
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

if [[ ${APPTAINER_VERSION} == "latest" ]] ; then
  v=$(curl -sL --retry 5 https://api.github.com/repos/apptainer/apptainer/releases/latest | jq -r ".tag_name")
  # the curl above is fragile, so retry until successful
  while [[ ${v} == "null" ]] ; do
    sleep 5
    v=$(curl -sL --retry 5 https://api.github.com/repos/apptainer/apptainer/releases/latest | jq -r ".tag_name")
  done
else
  v=${APPTAINER_VERSION}
fi

echo "::group::Installing Apptainer ${v}"
for deb in "apptainer_${v/v/}_amd64.deb" "apptainer-suid_${v/v/}_amd64.deb"; do
  sudo wget --tries 5 --quiet --timestamping --output-document /var/cache/apt/archives/${deb} https://github.com/apptainer/apptainer/releases/download/${v}/${deb}
  sudo apt-get -q -y install /var/cache/apt/archives/${deb}
done
echo "::endgroup::"

worker=$(echo ${SANDBOX_PATH} | sha256sum | awk '{print$1}')
if apptainer instance list | grep ${worker} ; then
  echo "Reusing exisitng Apptainer image from ${SANDBOX_PATH}"
 else
  echo "Starting Apptainer image from ${SANDBOX_PATH}"
  apptainer instance start --bind /cvmfs --bind ${GITHUB_WORKSPACE}:${GITHUB_WORKSPACE} --network ${NETWORK_TYPES:-bridge} ${SANDBOX_PATH} ${worker}
fi

echo "####################################################################"
echo "###################### Executing user payload ######################"
echo "VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV"

apptainer exec instance://${worker} /bin/bash -c "cd ${GITHUB_WORKSPACE}; ./action_payload.sh"
