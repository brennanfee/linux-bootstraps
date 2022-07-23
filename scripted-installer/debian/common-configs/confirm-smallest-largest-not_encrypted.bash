#!/usr/bin/env bash
# Author: Brennan Fee
# License: MIT License
#
# URL to install: bash <(curl -fsSL TBD)
#
# For the development version: TBD
#
# This script uses the deb-install script to install Debian/Ubuntu the "Arch"
# way.  The config script sets some values for a specific type of installation
# and then automatically calls the deb-install script.
#
# This version of the scripts prepares for this configuration:
#   - Will confirm settings with the user before executing.
#   - Main disk using the "smallest" selection option.
#   - Second disk using the "largest" selecton option.
#   - Encryption will not be used.
#   - The data folder will be configured.
#
# Bash strict mode
([[ -n ${ZSH_EVAL_CONTEXT} && ${ZSH_EVAL_CONTEXT} =~ :file$ ]] ||
 [[ -n ${BASH_VERSION} ]] && (return 0 2>/dev/null)) && SOURCED=true || SOURCED=false
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

## Set the variables here, make sure to export them
export AUTO_CONFIRM_SETTINGS=${AUTO_CONFIRM_SETTINGS:=1}
export AUTO_MAIN_DISK=${AUTO_MAIN_DISK:=smallest}
export AUTO_SECOND_DISK=${AUTO_SECOND_DISK:=largest}
export AUTO_ENCRYPT_DISKS=${AUTO_ENCRYPT_DISKS:=0}
export AUTO_USE_DATA_FOLDER=${AUTO_USE_DATA_FOLDER:=1}

#
## This downloads and runs the script.
#
script_file="${HOME}/deb-install.bash"
if [[ ! -f "${script_file}" ]]
then
  curl -fsSL https://tinyurl.com/deb-install/deb-install.bash --output "${script_file}"
fi

bash "${script_file}"

unset script_file
