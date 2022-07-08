#!/usr/bin/env bash
set -Euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR
IFS=$'\n\t'

if [ -z "${SANDBOX_PATH}" ]; then
  if [ ! -z "${EIC_SHELL_RELEASE}" ] && [ ! -z "${EIC_SHELL_PLATFORM_RELEASE}" ]; then
    echo "You set the variable release and platform-release together, this is not possible."
    echo "You either the variable pair release and platform or just plaform-release."
    exit 1
  fi


  if [ ! -z "${EIC_SHELL_PLATFORM}" ] && [ ! -z "${EIC_SHELL_PLATFORM_RELEASE}" ]; then
    echo "You set the variable platform and platform-release together, this is not possible."
    echo "You either the variable pair release and platform or just platform-release."
    exit 1
  fi

  if [ ! -z "${EIC_SHELL_PLATFORM}" ]; then
    export EIC_SHELL_PLATFORM_RELEASE="${EIC_SHELL_PLATFORM}:${EIC_SHELL_RELEASE}"
  fi
  export EIC_SHELL_PLATFORM=$(echo "${EIC_SHELL_PLATFORM_RELEASE}" | cut -d ':' -f 1)
  export EIC_SHELL_RELEASE=$(echo "${EIC_SHELL_PLATFORM_RELEASE}" | cut -d ':' -f 2)
  export SYSTEM=$(echo "${EIC_SHELL_PLATFORM_RELEASE}" | cut -d '/' -f 2 | cut -d '-' -f 2)
else
  if [ "${CONTAINER}" == "auto" ]; then
    export SYSTEM=$(echo "${SANDBOX_PATH}" | awk -F'x86_64-' '{print $2}' | cut -d '-' -f 1)
  else
    export SYSTEM=${CONTAINER}
  fi
fi

if [ "$(uname)" == "Linux" ]; then
  if [[ "${SYSTEM}" == *"mac"* ]]; then
    echo "You are trying to use a mac view on a linux system, this is not possible."
    exit 1
  fi
  if [ "$1" == "local" ]; then
    . run-linux.sh
  else
    $THIS/run-linux.sh
  fi
fi


if [ "$(uname)" == "Darwin" ]; then
  if [[ "${SYSTEM}" != *"mac"* ]]; then
    echo "You are trying to use a non macOS view on a macOS system, this is not possible."
    exit 1
  fi
  if [ "$1" == "local" ]; then
    . run-macOS.sh
  else
    $THIS/run-macOS.sh
  fi
fi
