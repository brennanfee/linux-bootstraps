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

if [ "$(getent passwd svcacct | wc -l || true)" -eq 1 ]; then
  runuser --shell=/bin/bash svcacct -c "/usr/bin/python3 -m pip install --user --no-warn-script-location pipx"

  runuser --shell=/bin/bash svcacct -c "/home/svcacct/.local/bin/pipx install --include-deps ansible"
  runuser --shell=/bin/bash svcacct -c "/home/svcacct/.local/bin/pipx inject ansible cryptography"
  runuser --shell=/bin/bash svcacct -c "/home/svcacct/.local/bin/pipx inject ansible paramiko"
fi
