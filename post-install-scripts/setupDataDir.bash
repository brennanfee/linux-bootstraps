#!/usr/bin/env bash

# Bash strict mode
([[ -n ${ZSH_EVAL_CONTEXT:-} && ${ZSH_EVAL_CONTEXT:-} =~ :file$ ]] ||
 [[ -n ${BASH_VERSION:-} ]] && (return 0 2>/dev/null)) && SOURCED=true || SOURCED=false
if ! ${SOURCED}
then
  set -o errexit # same as set -e
  set -o nounset # same as set -u
  set -o errtrace # same as set -E
  set -o pipefail
  set -o posix
  #set -o xtrace # same as set -x, turn on for debugging

  shopt -s inherit_errexit
  shopt -s extdebug
  IFS=$(printf '\n\t')
fi
# END Bash scrict mode

# Must be root
cur_user=$(id -u)
if [[ ${cur_user} -ne 0 ]]
then
  echo "This script must be run as root."
  exit 1
fi
unset cur_user

main () {
  # Data folder and data-user group
  ## On all my systems I create a /data folder.  Sometimes this is on the same disk as root other times it might be mounted from a secondary disk.  This is where I put all "server" files or files that are not user specific to my home folder.

  # Add the data-user group if it does not exist
  local group_exists
  group_exists=$(getent group data-user | wc -l || true)

  if [[ "${group_exists}" -eq 0 ]]
  then
    groupadd --system data-user
  fi

  if [[ ! -d /data ]]
  then
    mkdir -p /data
  fi

  chown -R root:data-user /data
  chmod -R g+w /data

  # Add some users to the group, we can't use $USER here because we are running this script as root
  local current_user
  current_user=$(logname)
  local usersToAdd=("${current_user}" svcacct ansible vagrant)

  for userToAdd in "${usersToAdd[@]}"
  do
    local user_exists
    user_exists=$(getent passwd "${userToAdd}" | wc -l || true)
    if [[ "${user_exists}" -eq 1 ]]
    then
      usermod -a -G data-user "${userToAdd}"
    fi
  done
}

main
