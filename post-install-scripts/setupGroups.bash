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
  # Can't use $USER as we are running this script as root/sudo
  local current_user
  current_user=$(logname)

  local usersToAdd=("${current_user}" svcacct ansible vagrant)
  local groupsToAdd=(sudo ssh _ssh users data-user vboxsf)

  for userToAdd in "${usersToAdd[@]}"
  do
    local user_exists
    user_exists=$(getent passwd "${userToAdd}" | wc -l || true)
    if [[ "${user_exists}" -eq 1 ]]
    then
      for groupToAdd in "${groupsToAdd[@]}"
      do
        local group_exists
        group_exists=$(getent group "${groupToAdd}" | wc -l || true)
        if [[ "${group_exists}" -eq 1 ]]
        then
          usermod -a -G "${groupToAdd}" "${userToAdd}"
        fi
      done
    fi
  done
}

main
