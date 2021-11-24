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

# Common installs
if command -v apt-get &> /dev/null
then
  DEBIAN_FRONTEND=noninteractive apt-get -y -q update

  DEBIAN_FRONTEND=noninteractive apt-get -y -q --no-install-recommends install apt-transport-https ca-certificates curl wget gnupg lsb-release build-essential dkms sudo acl git vim-nox python3-dev python3-setuptools python3-wheel python3-keyring python3-venv python3-pip python-is-python3 software-properties-common

  DEBIAN_FRONTEND=noninteractive apt-get -y -q autoremove
fi

# Distro specific installs
distro=$(lsb_release -i -s | tr '[:upper:]' '[:lower:]')
if [ "${distro}" == "debian" ]; then
  DEBIAN_FRONTEND=noninteractive apt-get -y -q --no-install-recommends install linux-image-amd64 linux-headers-amd64

  DEBIAN_FRONTEND=noninteractive apt-get -y -q --no-install-recommends install task-ssh-server apparmor firmware-linux-free os-prober
fi

if [ "${distro}" == "ubuntu" ]; then
  DEBIAN_FRONTEND=noninteractive apt-get -y -q --no-install-recommends install openssh-server openssh-client
fi
