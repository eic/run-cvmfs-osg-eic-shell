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
fi

if [ "$(uname)" == "Linux" ]; then
  $THIS/run-linux.sh
fi

if [ "$(uname)" == "Darwin" ]; then
  echo "You are trying to use this action on a macOS system, this is not possible."
  exit 1
fi
