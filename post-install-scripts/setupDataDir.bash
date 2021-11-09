#!/usr/bin/env bash

# Bash strict mode
# shellcheck disable=SC2154
([[ -n ${ZSH_EVAL_CONTEXT} && ${ZSH_EVAL_CONTEXT} =~ :file$ ]] ||
 [[ -n ${BASH_VERSION} ]] && (return 0 2>/dev/null)) && sourced=true || sourced=false
if ! ${sourced}; then
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

# Data folder and data-user group
## On all my systems I create a /data folder.  Sometimes this is on the same disk as root other times it might be mounted from a secondary disk.  This is where I put all "server" files or files that are not user specific to my home folder.

# Add the data-user group if it does not exist
if [ "$(getent group data-user | wc -l || true)" -eq 0 ]; then
  groupadd --system data-user
fi

if [ ! -d /data ]; then
  mkdir -p /data
fi

chown -R root:data-user /data
chmod -R g+w /data

# Add some users to the group, we can't use $USER here because we are running this script as root
current_user=$(logname)
usersToAdd=("${current_user}" svcacct ansible vagrant)

for userToAdd in "${usersToAdd[@]}"
do
  user_exists=$(getent passwd "${userToAdd}" | wc -l || true)
  if [ "${user_exists}" -eq 1 ]; then
    usermod -a -G data-user "${userToAdd}"
  fi
done
