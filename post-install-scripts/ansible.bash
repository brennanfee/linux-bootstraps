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

main() {
  local user_exists
  user_exists=$(getent passwd svcacct | wc -l)

  if [[ ${user_exists} == "1" ]]
  then
    runuser --shell=/bin/bash svcacct -c "/usr/bin/python3 -m pip install --user --no-warn-script-location pipx"

    runuser --shell=/bin/bash svcacct -c "/home/svcacct/.local/bin/pipx install --include-deps ansible"
    runuser --shell=/bin/bash svcacct -c "/home/svcacct/.local/bin/pipx inject ansible cryptography"
    runuser --shell=/bin/bash svcacct -c "/home/svcacct/.local/bin/pipx inject ansible paramiko"
  fi
}

main
