#!/usr/bin/env bash
set -Euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR
IFS=$'\n\t'

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
  echo "Did not find an EIC shell under this path: ${SANDBOX_PATH}"
  echo "Falling back to Docker container from ghcr.io"
  USE_DOCKER=true
else
  USE_DOCKER=false
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

if [ "${USE_DOCKER}" = "true" ]; then
  # Use Docker fallback
  DOCKER_IMAGE="ghcr.io/${EIC_SHELL_ORGANIZATION}/${EIC_SHELL_PLATFORM}:${EIC_SHELL_RELEASE}"
  echo "Using Docker image: ${DOCKER_IMAGE}"
  
  # Create a persistent container name based on the image (truncate hash to 12 chars)
  CONTAINER_NAME="eic-$(echo "${DOCKER_IMAGE}" | sha256sum | awk '{print substr($1,1,12)}')"
  
  # Check if container already exists
  if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Reusing existing Docker container: ${CONTAINER_NAME}"
    # Start the container if it's not running
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
      echo "Starting stopped container..."
      if ! docker start ${CONTAINER_NAME}; then
        echo "ERROR: Failed to start Docker container ${CONTAINER_NAME}"
        exit 1
      fi
    fi
  else
    echo "Creating new Docker container: ${CONTAINER_NAME}"
    # Create and start the container
    # Keep it running with tail -f /dev/null
    # Run as current user to avoid permission issues
    if ! docker run -d \
      --name ${CONTAINER_NAME} \
      --user $(id -u):$(id -g) \
      -v ${GITHUB_WORKSPACE}:${GITHUB_WORKSPACE} \
      -w ${GITHUB_WORKSPACE} \
      ${DOCKER_IMAGE} \
      tail -f /dev/null; then
      echo "ERROR: Failed to create and start Docker container from ${DOCKER_IMAGE}"
      echo "Make sure the image exists at ghcr.io and is accessible"
      exit 1
    fi
  fi
  
  echo "####################################################################"
  echo "###################### Executing user payload ######################"
  echo "VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV"
  
  # Execute the payload in the container
  if ! docker exec ${CONTAINER_NAME} /bin/bash ${GITHUB_WORKSPACE}/action_payload.sh; then
    echo "ERROR: Failed to execute payload in Docker container"
    exit 1
  fi
  
  exit 0
fi

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
  mkdir -p ${APPTAINER_DEB_CACHE}
  if [ ! -s ${APPTAINER_DEB_CACHE}/${deb} ] ; then
    wget --tries 5 --output-document ${APPTAINER_DEB_CACHE}/${deb} https://github.com/apptainer/apptainer/releases/download/${v}/${deb}
    echo "cache-update=true" >> $GITHUB_OUTPUT
  fi
  sudo rm -f /var/lib/man-db/auto-update
  sudo cp ${APPTAINER_DEB_CACHE}/${deb} /var/cache/apt/archives/${deb}
  sudo apt-get -q -y install /var/cache/apt/archives/${deb}
  sudo touch /var/lib/man-db/auto-update
done
echo "::endgroup::"

worker=$(echo ${SANDBOX_PATH} | sha256sum | awk '{print$1}')
if apptainer instance list | grep ${worker} ; then
  echo "Reusing exisitng Apptainer image from ${SANDBOX_PATH}"
 else
  echo "Starting Apptainer image from ${SANDBOX_PATH}"
  apptainer instance start --bind /cvmfs --bind ${GITHUB_WORKSPACE}:${GITHUB_WORKSPACE} ${SANDBOX_PATH} ${worker}
fi

echo "####################################################################"
echo "###################### Executing user payload ######################"
echo "VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV"

apptainer exec instance://${worker} /bin/bash -c "cd ${GITHUB_WORKSPACE}; ./action_payload.sh"
