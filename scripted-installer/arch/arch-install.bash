#!/usr/bin/env bash
# Author: Brennan Fee
# License: MIT License
# Version: 0.01  2021-11-09
#
# URL to install: bash <(curl -fsSL https://<path tbd>)
#
# This script installs Arch in an automated way.  Options, in the form of environment variables can be configured prior to calling this script to modify the defaults that would otherwise drive the installation.
#
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

echo -e "ERROR: This script is not yet implemented."
exit 1
