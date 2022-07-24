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
  local current_os
  current_os=$(lsb_release -i -s | tr "[:upper:]" "[:lower:]")

  local hostname
  hostname=$1
  if [[ ${hostname} == "" ]]
  then
    hostname="${current_os}-$((1 + RANDOM % 10000))"
  fi

  local domain=$2

  hostnamectl hostname "${hostname}"

  local the_line
  if [[ ${domain} == "" ]]
  then
    the_line="127.0.1.1 ${hostname}"
  else
    the_line="127.0.1.1 ${hostname}.${domain} ${hostname}"
  fi

  if grep -q '^127.0.1.1[[:blank:]]' /etc/hosts
  then
    # Update the line
    sed -i "/^127.0.1.1[[:blank:]]/ c\\${the_line}" /etc/hosts
  else
    # Add the line
    echo -E "${the_line}" >> /etc/hosts
  fi
}

main "$@"
