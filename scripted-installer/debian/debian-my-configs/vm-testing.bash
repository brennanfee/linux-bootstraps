#!/usr/bin/env bash
# Author: Brennan Fee
# License: MIT License
#
# URL to install: bash <(curl -fsSL TBD)
#
# For the development version: TBD
#
# Short URL:
# Github URL: https://raw.githubusercontent.com/brennanfee/linux-bootstraps/main/scripted-installer/debian/my-configs/auto-stable-singleDish.bash
#
# This script uses the deb-install script to install Debian/Ubuntu the "Arch"
# way.  The config script sets some values for a specific type of installation
# and then automatically calls the deb-install script.
#
# This version of the scripts prepares for this configuration:
#   - Main disk using the "smallest" selection option.
#   - Any secondary disks will be ignored.
#   - The disk(s) will not be encrypted, encrypted disks don't compress well in VMs.
#   - The data folder will be configured.
#   - Debian testing will be installed
#
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

## Set the variables here, make sure to export them
export AUTO_CONFIRM_SETTINGS=${AUTO_CONFIRM_SETTINGS:=0}
export AUTO_MAIN_DISK=${AUTO_MAIN_DISK:=smallest}
export AUTO_SECOND_DISK=${AUTO_SECOND_DISK:=ignore}
export AUTO_ENCRYPT_DISKS=${AUTO_ENCRYPT_DISKS:=0}
export AUTO_USE_DATA_FOLDER=${AUTO_USE_DATA_FOLDER:=1}

export AUTO_INSTALL_EDITION=${AUTO_INSTALL_EDITION:=testing}

#
## This downloads and runs the script.
#
script_file="${HOME}/deb-install.bash"
if [[ ! -f "${script_file}" ]]
then
  # To support testing of other versions of the install script (local versions, branches, etc.)
  if [[ "${CONFIG_SCRIPT_SOURCE:=}" != "" ]]
  then
    curl -fsSL "${CONFIG_SCRIPT_SOURCE}" --output "${script_file}"
  else
    curl -fsSL https://tinyurl.com/deb-install/deb-install.bash --output "${script_file}"
  fi
fi

bash "${script_file}"

unset script_file
