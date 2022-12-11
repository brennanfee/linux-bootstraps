#!/usr/bin/env bash
# Author: Brennan A. Fee
# License: MIT License
#
# This script uses the deb-install script to install Debian/Ubuntu the "Arch"
# way.  The config script sets some values for a specific type of installation
# and then automatically calls the deb-install script.
#
# Short URL:
# Github URL:
#
#
##################  MODIFY THIS SECTION
## Set the deb-install variables\options you want here, make sure to export them.
set_exports() {
  export AUTO_INSTALL_OS=${AUTO_INSTALL_OS:=debian}
  export AUTO_INSTALL_EDITION=${AUTO_INSTALL_EDITION:=stable}
  export AUTO_KERNEL_VERSION=${AUTO_KERNEL_VERSION:=default}

  export AUTO_MAIN_DISK=${AUTO_MAIN_DISK:=smallest}
  export AUTO_SECOND_DISK=${AUTO_SECOND_DISK:=largest}
  export AUTO_ENCRYPT_DISKS=${AUTO_ENCRYPT_DISKS:=1}

  export AUTO_USE_DATA_FOLDER=${AUTO_USE_DATA_FOLDER:=1}

  export AUTO_DOMAIN=${AUTO_DOMAIN:=bfee.org}
  export AUTO_USERNAME=${AUTO_USERNAME:=brennan}
}
##################  DO NOT MODIFY BELOW THIS SECTION

check_root() {
  print_info "Checking root permissions..."

  local user_id
  user_id=$(id -u)
  if [[ "${user_id}" != "0" ]]
  then
    local RED
    local RESET
    RED="$(tput setaf 1)"
    RESET="$(tput sgr0)"
    echo -e "${RED}ERROR! You must execute the script as the 'root' user.${RESET}\n"
    exit 1
  fi
}

download_deb_installer() {
  local script_file=$1

  local script_url="https://raw.githubusercontent.com/brennanfee/linux-bootstraps/main/scripted-installer/debian/deb-install.bash"

  if [[ ! -f "${script_file}" ]]
  then
    # To support testing of other versions of the install script (local versions, branches, etc.)
    if [[ "${CONFIG_SCRIPT_SOURCE:=}" != "" ]]
    then
      curl -fsSL "${CONFIG_SCRIPT_SOURCE}" --output "${script_file}"
    else
      curl -fsSL "${script_url}" --output "${script_file}"
    fi
  fi
}

read_input_options() {
  while [[ "${1:-}" != "" ]]
  do
    case $1 in
      -c | --confirm)
        export AUTO_CONFIRM_SETTINGS=1
        ;;
      -d | --debug)
        export AUTO_IS_DEBUG=1
        ;;
      -r | --reboot)
        export AUTO_REBOOT=1
        ;;
      -s | --script)
        shift
        CONFIG_SCRIPT_SOURCE=$1
        ;;
      *)
        noop
        ;;
    esac

    shift
  done
}

main() {
  local script_file
  script_file="/tmp/deb-install.bash"

  check_root
  set_exports
  read_input_options "$@"

  download_deb_installer "${script_file}"

  # Now run the script
  bash "${script_file}"
}

main "$@"
