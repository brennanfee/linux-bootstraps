#!/usr/bin/env bash
# This script uses the deb-install script to install Debian/Ubuntu the "Arch"
# way.  The config script sets some values for a specific type of installation
# and then automatically calls the deb-install script.
#

script_file="${HOME}/deb-install.bash"

download_deb_installer() {
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

main() {
  set_exports
  download_deb_installer
  bash "${script_file}"
}

##################
set_exports() {
  ## Set the deb-install variables\options here, make sure to export them.
  # TODO: Complete this section, below is a sample
  export AUTO_MAIN_DISK=${AUTO_MAIN_DISK:=smallest}
}
##################

main
unset script_file
