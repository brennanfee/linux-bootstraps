#!/usr/bin/env bash

# Bash strict mode
# shellcheck disable=SC2154
([[ -n ${ZSH_EVAL_CONTEXT} && ${ZSH_EVAL_CONTEXT} =~ :file$ ]] ||
 [[ -n ${BASH_VERSION} ]] && (return 0 2>/dev/null)) && SOURCED=true || SOURCED=false
if ! ${SOURCED}; then
  set -o errexit # same as set -e
  set -o nounset # same as set -u
  set -o errtrace # same as set -E
  set -o pipefail
  set -o posix
  #set -o xtrace # same as set -x, turn on for debugging

  shopt -s extdebug
  IFS=$(printf '\n\t')
fi
# END Bash scrict mode

# Must be root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root."
  exit 1
fi

distro=$(lsb_release -i -s | tr '[:upper:]' '[:lower:]')

# For Ubuntu, install HWE kernels if they are available
if [ "${distro}" = "ubuntu" ]; then
  HWE_KERNEL_EDGE_PKG="linux-generic-hwe-$(lsb_release -r -s)-edge"
  HWE_KERNEL_PKG="linux-generic-hwe-$(lsb_release -r -s)"

  EDGE_PKG_EXISTS=$(apt-cache search --names-only "^${HWE_KERNEL_EDGE_PKG}$" | wc -l)
  HWE_PKG_EXISTS=$(apt-cache search --names-only "^${HWE_KERNEL_PKG}$" | wc -l)

  if [ "${EDGE_PKG_EXISTS}" -eq 1 ]; then
    DEBIAN_FRONTEND=noninteractive apt-get -y -q --no-install-recommends install "${HWE_KERNEL_EDGE_PKG}"
  elif [ "${HWE_PKG_EXISTS}" -eq 1 ]; then
    DEBIAN_FRONTEND=noninteractive apt-get -y -q --no-install-recommends install "${HWE_KERNEL_PKG}"
  fi
fi
