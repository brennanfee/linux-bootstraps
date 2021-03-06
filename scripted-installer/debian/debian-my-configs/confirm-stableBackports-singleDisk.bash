#!/usr/bin/env bash
# Author: Brennan Fee
# License: MIT License
#
# URL to install: bash <(curl -fsSL TBD)
#
# For the development version: TBD
#
# Github URL: https://raw.githubusercontent.com/brennanfee/linux-bootstraps/main/scripted-installer/debian/my-configs/confirm-stableBackports-singleDisk.bash
#
# This script uses the deb-install script to install Debian/Ubuntu the "Arch"
# way.  The config script sets some values for a specific type of installation
# and then automatically calls the deb-install script.
#
# This version of the scripts prepares for this configuration:
#   - Will confirm settings with the user before executing.
#   - Main disk using the "smallest" selection option.
#   - Any secondary disks will be ignored.
#   - The disk(s) will be encrypted.
#   - The data folder will be configured.
#   - Debian stable will be installed and the "backports" kernel will be used.
#   - Domain of bfee.org and a default use of brennan will be created.
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
export AUTO_CONFIRM_SETTINGS=${AUTO_CONFIRM_SETTINGS:=1}
export AUTO_MAIN_DISK=${AUTO_MAIN_DISK:=smallest}
export AUTO_SECOND_DISK=${AUTO_SECOND_DISK:=ignore}
export AUTO_ENCRYPT_DISKS=${AUTO_ENCRYPT_DISKS:=1}
export AUTO_USE_DATA_FOLDER=${AUTO_USE_DATA_FOLDER:=1}

export AUTO_INSTALL_EDITION=${AUTO_INSTALL_EDITION:=stable}
export AUTO_KERNEL_VERSION=${AUTO_KERNEL_VERSION:=backport}

export AUTO_DOMAIN=${AUTO_DOMAIN:=bfee.org}
export AUTO_USERNAME=${AUTO_USERNAME:=brennan}

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
