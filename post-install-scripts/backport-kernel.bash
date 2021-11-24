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

contains_element() {
  #check if an element exist in a string
  for e in "${@:2}"; do [[ ${e} == "$1" ]] && break; done
}

package_exists() {
  arch-chroot /mnt apt-cache show "$1" &> /dev/null
  return $?
}

distro=$(lsb_release -i -s | tr '[:upper:]' '[:lower:]')
DPKG_ARCH=$(dpkg --print-architecture) # Something like amd64, arm64

# For Ubuntu, install HWE kernels if they are available
if [ "${distro}" = "ubuntu" ]; then
  release_version=$(lsb_release -r -s)
  HWE_KERNEL_EDGE_PKG="linux-generic-hwe-${release_version}-edge"
  HWE_KERNEL_PKG="linux-generic-hwe-${release_version}"

  EDGE_PKG_EXISTS=$(apt-cache search --names-only "^${HWE_KERNEL_EDGE_PKG}$" | wc -l)
  HWE_PKG_EXISTS=$(apt-cache search --names-only "^${HWE_KERNEL_PKG}$" | wc -l)

  if [ "${EDGE_PKG_EXISTS}" -eq 1 ]; then
    DEBIAN_FRONTEND=noninteractive apt-get -y -q --no-install-recommends install "${HWE_KERNEL_EDGE_PKG}"
  elif [ "${HWE_PKG_EXISTS}" -eq 1 ]; then
    DEBIAN_FRONTEND=noninteractive apt-get -y -q --no-install-recommends install "${HWE_KERNEL_PKG}"
  fi
fi

# For Debian, check to see if there is a backports kernel
if [ "${distro}" = "debian" ]; then
  dont_support_backports=("sid" "unstable" "rc-buggy" "experimental")
  # Can't use lsb_release codename here as it always gives the named codename and not the installed edition (so bullseye instead of stable for instance).
  edition=$(sed -rn 's/deb http[^ ]* ([^ ]*) .*/\1/p' /etc/apt/sources.list | head -n 1)
  if ! contains_element "${edition}" "${dont_support_backports[@]}"; then
    # Check to see the package exists in backports, if not we'll just install the default kernel
    if package_exists "linux-image-${DPKG_ARCH}/${edition}-backports"; then
      DEBIAN_FRONTEND=noninteractive apt-get -y -q --no-install-recommends -t "${edition}-backports" "linux-image-${DPKG_ARCH}" "linux-headers-${DPKG_ARCH}"
    fi
  fi
fi
