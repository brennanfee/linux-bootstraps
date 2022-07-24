#!/usr/bin/env bash
# Author: Brennan Fee
# License: MIT License
# Version: 0.01  2021-11-09
#
# URL to install: bash <(curl -fsSL https://<path tbd>)
#
# TBD
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

### START: Log Functions

write_log() {
  echo -e "LOG: ${1}" >> "${LOG}"
}

write_log_password() {
  if [[ ${IS_DEBUG} == "1" ]]; then
    echo -e "LOG: ${1}" >> "${LOG}"
  else
    local val
    val=${1//:*/: ******}
    echo -e "LOG: ${val}" >> "${LOG}"
  fi
}

write_log_blank() {
  echo -e "" >> "${LOG}"
}

write_log_spacer() {
  echo -e "------" >> "${LOG}"
}

log_values() {
  write_log "Post Prompt Values"
  write_log_spacer

  write_log_blank
  write_log "INSTALLER_DISTRO: '${INSTALLER_DISTRO}'"
  write_log "SYS_ARCH: '${SYS_ARCH}'"
  write_log "DPKG_ARCH: '${DPKG_ARCH}'"
  write_log "UEFI: '${UEFI}'"
  write_log "XPINGS: '${XPINGS}'"
  write_log_blank
  write_log "is_auto_install: '${is_auto_install}'"
  write_log "use_second_disk: '${use_second_disk}'"

  write_log_blank
  write_log "AUTO_INSTALL: '${AUTO_INSTALL}'"
  write_log "INSTALL_OS: '${INSTALL_OS}'"
  write_log "INSTALL_EDITION: '${INSTALL_EDITION}'"
  write_log "USE_BACKPORTS: '${USE_BACKPORTS}'"
  write_log "SUPPORT_HIBERNATION: '${SUPPORT_HIBERNATION}'"
  write_log "KEYMAP: '${KEYMAP}'"
  write_log "HOSTNAME: '${HOSTNAME}'"
  write_log "DOMAIN: '${DOMAIN}'"
  write_log "TIMEZONE: '${TIMEZONE}'"
  write_log "MAIN_DISK_SELECTION: '${MAIN_DISK_SELECTION}'"
  write_log "SECOND_DISK_SELECTION: '${SECOND_DISK_SELECTION}'"
  write_log "ENCRYPT_DISKS: '${ENCRYPT_DISKS}'"
  write_log_password "DISK_PWD: '${DISK_PWD}'"
  write_log "ROOT_DISABLED: '${ROOT_DISABLED}'"
  write_log_password "ROOT_PWD: '${ROOT_PWD}'"
  write_log "CREATE_USER: '${CREATE_USER}'"
  write_log "USERNAME: '${USERNAME}'"
  write_log_password "USER_PWD: '${USER_PWD}'"

  write_log_blank
  write_log "MULTI_DISK_SYSTEM: '${MULTI_DISK_SYSTEM}'"
  write_log "MAIN_DISK: '${MAIN_DISK}'"
  write_log "SECOND_DISK: '${SECOND_DISK}'"

  write_log_blank
  write_log_spacer
}

### START: Log Functions

### START: Print Functions

print_line() {
  printf "%$(tput cols)s\n" | tr ' ' '-'
  echo -e "------" >> "${LOG}"
}

blank_line() {
  echo "" |& tee -a "${LOG}"
}

print_title() {
  clear
  print_line
  echo -e "# ${Bold}$1${Reset}"
  echo -e "SECTION: ${1}" >> "${LOG}"
  print_line
  blank_line
}

print_title_info() {
  T_COLS=$(tput cols)
  echo -e "${Bold}$1${Reset}\n" | fold -sw $((T_COLS - 18)) | sed 's/^/\t/'
  echo -e "TITLE: ${1}" >> "${LOG}"
}

print_status() {
  T_COLS=$(tput cols)
  echo -e "$1${Reset}" | fold -sw $((T_COLS - 1))
  echo -e "STATUS: ${1}" >> "${LOG}"
}

print_info() {
  T_COLS=$(tput cols)
  echo -e "${Bold}$1${Reset}" | fold -sw $((T_COLS - 1))
  echo -e "INFO: ${1}" >> "${LOG}"
}

print_warning() {
  T_COLS=$(tput cols)
  echo -e "${Yellow}$1${Reset}" | fold -sw $((T_COLS - 1))
  echo -e "WARN: ${1}" >> "${LOG}"
}

print_success() {
  T_COLS=$(tput cols)
  echo -e "${Green}$1${Reset}" | fold -sw $((T_COLS - 1))
  echo -e "SUCCESS: ${1}" >> "${LOG}"
}

error_msg() {
  T_COLS=$(tput cols)
  echo -e "${Red}$1${Reset}\n" | fold -sw $((T_COLS - 1))
  echo -e "ERROR: ${1}" >> "${LOG}"
  exit 1
}

pause_output() {
  print_line
  if [[ ${is_auto_install} == "0" ]]; then
    read -re -sn 1 -p "Press enter to continue..."
  fi
}

invalid_option() {
  print_line
  print_warning "Invalid option. Try again."
}

invalid_option_error() {
  print_line
  error_msg "Invalid option. Try again."
}

### END: Print Functions

### START: Verification Functions

# Fix this, if connection test fails, try and prompt the user for how they wish to connect (usually wifi, so a SSID and password?).
check_network_connection() {
  print_info "Checking network connectivity..."

  XPINGS=$((XPINGS + 1))
  connection_test() {
    ping -q -w 1 -c 1 "$(ip r | grep default | awk 'NR==1 {print $3}')" &>/dev/null && return 1 || return 0
  }

  set +o pipefail
  WIRED_DEV=$(ip link | grep "ens\|eno\|enp" | awk '{print $2}' | sed 's/://' | sed '1!d')
  write_log "Wired device: ${WIRED_DEV}"

  WIRELESS_DEV=$(ip link | grep wlp | awk '{print $2}' | sed 's/://' | sed '1!d')
  write_log "Wireless device: ${WIRELESS_DEV}"
  set -o pipefail

  if connection_test; then
    print_warning "ERROR! Connection not Found."
    print_info "Network Setup"
    local _connection_opts=("Wired Automatic" "Wired Manual" "Wireless" "Skip")
    PS3="Enter your option: "
    # shellcheck disable=SC2034
    select CONNECTION_TYPE in "${_connection_opts[@]}"; do
      case "${REPLY}" in
      1)
        systemctl start "dhcpcd@${WIRED_DEV}.service"
        break
        ;;
      2)
        systemctl stop "dhcpcd@${WIRED_DEV}.service"
        read -rp "IP Address: " IP_ADDR
        read -rp "Submask: " SUBMASK
        read -rp "Gateway: " GATEWAY
        ip link set "${WIRED_DEV}" up
        ip addr add "${IP_ADDR}/${SUBMASK}" dev "${WIRED_DEV}"
        ip route add default via "${GATEWAY}"
        break
        ;;
      3)
        wifi-menu "${WIRELESS_DEV}"
        break
        ;;
      4)
        error_msg "No network setup, exiting."
        break
        ;;
      *)
        invalid_option
        ;;
      esac
    done
    if [[ ${XPINGS} -gt 2 ]]; then
      error_msg "Can't establish connection. exiting..."
    fi
    [[ ${REPLY} -ne 5 ]] && check_network_connection
  else
    print_info "Connection found."
  fi
}

### END: Verification Functions

### START: Prompts & User Interaction

ask_for_keymap() {
  write_log "In ask for keymap."

  if [[ -n ${AUTO_KEYMAP:-} ]]; then
    KEYMAP=${AUTO_KEYMAP}
  else
    KEYMAP="us" # the default

    if [[ ${is_auto_install} == "0" ]]; then
      print_title "Keymap"
      print_title_info "Pick a keymap for this machine.  Press enter to accept the default."
      local input
      read -rp "Keymap [${KEYMAP}]: " input
      if [[ ${input} != "" ]]; then
        KEYMAP=${input}
      fi
    fi
  fi

  write_log "Kemap to use: ${KEYMAP}"
}

ask_for_os_to_install() {
  write_log "In ask for os to install."

  if [[ -n ${AUTO_INSTALL_OS:-} ]]; then
    INSTALL_OS=$(echo "${AUTO_INSTALL_OS}" | tr "[:upper:]" "[:lower:]")
  else
    INSTALL_OS="debian" # the default

    if [[ ${is_auto_install} == "0" ]]; then
      print_title "OS To Install"
      print_title_info "Pick an OS to install."
      select input_os in "${SUPPORTED_OS_DISPLAY[@]}"; do
        if contains_element "${input_os}" "${SUPPORTED_OS_DISPLAY[@]}"; then
          break
        else
          invalid_option
        fi
      done
      INSTALL_OS=$(echo "${input_os}" | tr "[:upper:]" "[:lower:]")
    fi
  fi

  write_log "Selected OS before validation: ${INSTALL_OS}"

  # Validate it
  if ! contains_element "${INSTALL_OS}" "${SUPPORTED_OS[@]}"; then
    error_msg "ERROR! Invalid OS to install selected."
  fi

  write_log "OS to install: ${INSTALL_OS}"
}

ask_for_edition_to_install() {
  write_log "In ask for os edition to install."

  if [[ -n ${AUTO_INSTALL_EDITION:-} ]]; then
    INSTALL_EDITION=$(echo "${AUTO_INSTALL_EDITION}" | tr "[:upper:]" "[:lower:]")
  else
    if [[ ${INSTALL_OS} == "debian" ]]; then
      INSTALL_EDITION="stable" # the default for debian
    else
      INSTALL_EDITION="focal" # the (current) default for ubuntu
    fi

    if [[ ${is_auto_install} == "0" ]]; then
      print_title "OS Edition To Install"
      print_title_info "Enter an edition to install.  Press enter to accept the default."

      local input
      read -rp "OS Edition [${INSTALL_EDITION}]: " input
      if [[ ${input} != "" ]]; then
        INSTALL_EDITION=${input}
      fi

      INSTALL_EDITION=$(echo "${INSTALL_EDITION}" | tr "[:upper:]" "[:lower:]")
    fi
  fi

  write_log "OS edition to install: ${INSTALL_EDITION}"
}

ask_about_backports() {
  write_log "In ask about backports."

  if [[ -n ${AUTO_USE_BACKPORTS_OR_HWE:-} ]]; then
    local input
    input=$(echo "${AUTO_USE_BACKPORTS_OR_HWE}" | tr "[:upper:]" "[:lower:]")
    if [[ ${input} == "no" || ${input} == "false" || ${input} == "0" ]]; then
      USE_BACKPORTS=0
    else
      USE_BACKPORTS=1
    fi
  else
    USE_BACKPORTS=1 # The default

    if [[ ${is_auto_install} == "0" ]]; then
      print_title "Backports support or HWE Kernel"
      print_title_info "Should backports or the HWE Kernel be installed?"
      local yes_no=('Yes' 'No')
      local option
      select option in "${yes_no[@]}"; do
        if contains_element "${option}" "${yes_no[@]}"; then
          break
        else
          invalid_option
        fi
      done
      option=$(echo "${option}" | tr "[:upper:]" "[:lower:]")

      case "${option}" in
        yes)
          USE_BACKPORTS=1
          ;;

        no)
          USE_BACKPORTS=0
          ;;

        *)
          USE_BACKPORTS=1
          ;;
      esac
    fi
  fi

  write_log "Should install backports: ${USE_BACKPORTS}"
}

ask_for_hostname() {
  write_log "In ask for hostname."

  if [[ -n ${AUTO_HOSTNAME:-} ]]; then
    HOSTNAME="${AUTO_HOSTNAME}"
  else
    # The default
    HOSTNAME="${INSTALL_OS}-$((1 + RANDOM % 10000))"

    if [[ ${is_auto_install} == "0" ]]; then
      print_title "Hostname"
      print_title_info "Enter a hostname for this machine.  Press enter to accept the default."
      local input
      read -rp "Hostname [${HOSTNAME}]: " input
      if [[ ${input} != "" ]]; then
        HOSTNAME=${input}
      fi
    fi
  fi

  write_log "Hostname to use: ${HOSTNAME}"
}

ask_for_domain() {
  write_log "In ask for domain."

  if [[ -n ${AUTO_DOMAIN:-} ]]; then
    DOMAIN="${AUTO_DOMAIN}"
  else
    # The default is blank, not using a domain
    DOMAIN=""

    if [[ ${is_auto_install} == "0" ]]; then
      print_title "Domain"
      print_title_info "Enter a domain for this machine.  Press enter to accept the default."
      local input
      read -rp "Domain [${DOMAIN}]: " input
      if [[ ${input} != "" ]]; then
        DOMAIN=${input}
      fi
    fi
  fi

  write_log "Domain to use: ${DOMAIN}"
}

ask_for_timezone() {
  write_log "In ask for timezone."

  if [[ -n ${AUTO_TIMEZONE:-} ]]; then
    TIMEZONE="${AUTO_TIMEZONE}"
  else
    # The default is blank, not using a domain
    TIMEZONE="America/Chicago"

    if [[ ${is_auto_install} == "0" ]]; then
      print_title "Timezone"
      print_title_info "Enter a timezone for this machine.  Press enter to accept the default."
      local input
      read -rp "Domain [${TIMEZONE}]: " input
      if [[ ${input} != "" ]]; then
        TIMEZONE=${input}
      fi
    fi
  fi

  write_log "Timezone to use: ${TIMEZONE}"
}

ask_for_main_disk() {
  write_log "In ask for main disk."

  print_info "Collecting disks..."
  local devices_list
  mapfile -t devices_list < <(lsblk --nodeps --noheading --list --include 3,8,22,65,202,253,259 | awk '{print "/dev/" $1}')

  if [[ ${#devices_list[@]} == 1 ]]; then
    # There is only 1 disk in the system, no need to prompt or do a match
    MAIN_DISK_SELECTION="auto"
    MAIN_DISK=${devices_list[0]}
    return
  fi

  if [[ -n ${AUTO_MAIN_DISK:-} ]]; then
    MAIN_DISK_SELECTION=$(echo "${AUTO_MAIN_DISK}" | tr "[:upper:]" "[:lower:]")
    SELECTED_OPTION=${MAIN_DISK_SELECTION}
  else
    # The defaults
    MAIN_DISK_SELECTION='smallest'
    SELECTED_OPTION=${MAIN_DISK_SELECTION}

    if [[ ${is_auto_install} == "0" ]]; then
      print_title "Main Disk Selection"
      print_title_info "How do you want to determine the disk to install? Select 'Default' to use the default option, select 'Direct' to type in a device manually, 'Smallest' to auto-select the smallest disk, 'Largest' to auto-select the largest disk, or 'Pick' to be given a list of disks to select from.\n\nThe default option is: '${MAIN_DISK_SELECTION}'"
      local disk_options=('Default' 'Direct' 'Smallest' 'Largest' 'Pick')
      local option
      select option in "${disk_options[@]}"; do
        if contains_element "${option}" "${disk_options[@]}"; then
          break
        else
          invalid_option
        fi
      done
      if [[ ${option} == "Default" ]]; then
        option=${MAIN_DISK_SELECTION}
      fi
      MAIN_DISK_SELECTION=$(echo "${MAIN_DISK_SELECTION}" | tr "[:upper:]" "[:lower:]")

      case "${MAIN_DISK_SELECTION}" in
        /dev/*)
          SELECTED_OPTION=${MAIN_DISK_SELECTION}
          MAIN_DISK_SELECTION="direct"
          ;;

        direct)
          blank_line
          read -rp "Enter in the device: " input
          SELECTED_OPTION=${input}
          ;;

        smallest)
          SELECTED_OPTION='smallest'
          ;;

        largest)
          SELECTED_OPTION='largest'
          ;;

        pick)
          blank_line
          print_title_info "Select which disk to use for the main installation (where root and boot will go)."
          lsblk --nodeps --list --include 3,8,22,65,202,253,259 --output "name,size,type"
          blank_line
          PS3="Enter your option: "
          echo -e "Select main drive:\n"
          local device
          select device in "${devices_list[@]}"; do
            if contains_element "${device}" "${devices_list[@]}"; then
              break
            else
              invalid_option
            fi
          done
          SELECTED_OPTION=${device}
          ;;

        *)
          error_msg "Invalid main disk selection option."
          ;;
      esac
    fi
  fi

  case "${SELECTED_OPTION}" in
    /dev/*)
      MAIN_DISK_SELECTION="direct"
      ;;

    smallest)
      SELECTED_OPTION="/dev/$(lsblk --nodeps --noheading --list --include 3,8,22,65,202,253,259 --sort SIZE -o NAME | head -n 1)"
      ;;

    largest)
      SELECTED_OPTION="/dev/$(lsblk --nodeps --noheading --list --include 3,8,22,65,202,253,259 --sort SIZE -o NAME | tail -1)"
      ;;

    *)
      error_msg "Unable to determine main disk."
      ;;
  esac

  # Verify it is a valid disk/device locator
  if [[ ! -b ${SELECTED_OPTION} ]]; then
    error_msg "ERROR! Invalid main disk selected '${SELECTED_OPTION}'."
  fi

  MAIN_DISK=${SELECTED_OPTION}

  write_log "Main disk selected: ${MAIN_DISK}"
}

ask_for_second_disk() {
  write_log "In ask for second disk."

  print_info "Collecting disks..."
  local devices_list
  mapfile -t devices_list < <(lsblk --nodeps --noheading --list --include 3,8,22,65,202,253,259 | awk '{print "/dev/" $1}' | grep -v "${MAIN_DISK}")

  if [[ ${#devices_list[@]} == 0 ]]; then
    # There is only 1 disk in the system, no need to prompt or do a match
    MULTI_DISK_SYSTEM=0
    SECOND_DISK_SELECTION="auto"
    SECOND_DISK="ignore"
    return
  fi

  MULTI_DISK_SYSTEM=1

  if [[ -n ${AUTO_SECOND_DISK:-} ]]; then
    SECOND_DISK_SELECTION=$(echo "${AUTO_SECOND_DISK}" | tr "[:upper:]" "[:lower:]")
    SELECTED_OPTION=${SECOND_DISK_SELECTION}
  else
    # The defaults
    SECOND_DISK_SELECTION='largest'
    SELECTED_OPTION=${SECOND_DISK_SELECTION}

    if [[ ${#devices_list[@]} == 1 && (${IS_IN_AUTO_INSTALL} == 1) ]]; then
      SECOND_DISK_SELECTION="auto"
      SECOND_DISK=${devices_list[0]}
      return
    fi

    if [[ ${#devices_list[@]} == 1 && (${IS_IN_AUTO_INSTALL} == 0) ]]; then
      # There is only 1 other disk in the system, we only need to ask if they want to ignore it...
      print_title "Second Disk Selection"
      print_title_info "Only one additional disk other then the selected main disk ('${MAIN_DISK}') has been identified.  Do you wish to select it for use or not?
      Select 'Yes' to accept and use it or 'No' to ignore the second disk and only install to the main disk."
      local yes_no=('Yes' 'No')
      local option
      select option in "${yes_no[@]}"; do
        if contains_element "${option}" "${yes_no[@]}"; then
          break
        else
          invalid_option
        fi
      done
      option=$(echo "${option}" | tr "[:upper:]" "[:lower:]")

      case "${option}" in
        yes)
          SECOND_DISK_SELECTION="auto"
          SECOND_DISK=${devices_list[0]}
          ;;

        no)
          SECOND_DISK_SELECTION="ignore"
          SECOND_DISK="ignore"
          ;;

        *)
          # Default is to ignore the second disk which is safest, no need for error here
          SECOND_DISK_SELECTION="ignore"
          SECOND_DISK="ignore"
          ;;
      esac

      return
    fi

    if [[ ${is_auto_install} == "0" ]]; then
      print_title "Second Disk Selection"
      print_title_info "How do you want to determine the second disk to use? Select 'Default' to use the default option, select 'Ignore' to ignore the other disks and only use the main disk, 'Direct' to type in a device to use manually, 'Smallest' to auto-select the smallest disk, 'Largest' to auto-select the largest disk, or 'Pick' to be given a list of disks to select from.\n\nThe default option is: '${SECOND_DISK_SELECTION}'"
      local disk_options=('Default' 'Ignore' 'Direct' 'Smallest' 'Largest' 'Pick')
      local option
      select option in "${disk_options[@]}"; do
        if contains_element "${option}" "${disk_options[@]}"; then
          break
        else
          invalid_option
        fi
      done
      if [[ ${option} == "Default" ]]; then
        option=${SECOND_DISK_SELECTION}
      fi
      SECOND_DISK_SELECTION=$(echo "${SECOND_DISK_SELECTION}" | tr "[:upper:]" "[:lower:]")

      case "${SECOND_DISK_SELECTION}" in
        /dev/*)
          SELECTED_OPTION=${SECOND_DISK_SELECTION}
          ;;

        ignore)
          SELECTED_OPTION="ignore"
          ;;

        direct)
          blank_line
          read -rp "Enter in the device: " INPUT_DEVICE
          SELECTED_OPTION=${INPUT_DEVICE}
          ;;

        smallest)
          SELECTED_OPTION='smallest'
          ;;

        largest)
          SELECTED_OPTION='largest'
          ;;

        pick)
          blank_line
          print_title_info "Select which disk to use for the seondary disk (where /home and /data will go)."
          lsblk --nodeps --list --include 3,8,22,65,202,253,259 --output "name,size,type"
          blank_line
          PS3="Enter your option: "
          echo -e "Select second drive:\n"
          local device
          select device in "${devices_list[@]}"; do
            if contains_element "${device}" "${devices_list[@]}"; then
              break
            else
              invalid_option
            fi
          done
          SELECTED_OPTION=${device}
          ;;

      *)
        error_msg "Invalid second disk selection method."
        ;;
      esac
    fi
  fi

  case "${SELECTED_OPTION}" in
    /dev/*)
      SECOND_DISK_SELECTION="direct"
      ;;

    ignore)
      SECOND_DISK_SELECTION="ignore"
      SECOND_DISK="ignore"
      return
      ;;

    smallest)
      SELECTED_OPTION=$(lsblk --nodeps --noheading --list --include 3,8,22,65,202,253,259 --sort SIZE | awk '{print "/dev/" $1}' | grep -v "${MAIN_DISK}" | head -n 1)
      ;;

    largest)
      SELECTED_OPTION=$(lsblk --nodeps --noheading --list --include 3,8,22,65,202,253,259 --sort SIZE | awk '{print "/dev/" $1}' | grep -v "${MAIN_DISK}" | tail -1)
      ;;

    *)
      error_msg "Unable to determine second disk selected."
      ;;
  esac

  # Verify it is a valid disk/device locator
  if [[ ! -b ${SELECTED_OPTION} ]]; then
    error_msg "ERROR! Invalid second disk selected '${SELECTED_OPTION}'."
  fi

  # Verify it is not the same as the main disk
  if [[ "${SELECTED_OPTION}" == "${MAIN_DISK}" ]]; then
    error_msg "ERROR! Main disk and second disk can not be the same disk."
  fi

  SECOND_DISK=${SELECTED_OPTION}

  write_log "Second disk selected: ${SECOND_DISK}"
}

ask_should_encrypt_disks() {
  write_log "In ask should encrypt disks."

  if [[ -n ${AUTO_ENCRYPT_DISKS:-} ]]; then
    local input
    input=$(echo "${AUTO_ENCRYPT_DISKS}" | tr "[:upper:]" "[:lower:]")
    if [[ ${input} == "no" || ${input} == "false" ]]; then
      ENCRYPT_DISKS=0
    else
      ENCRYPT_DISKS=1
    fi
  else
    ENCRYPT_DISKS=1 # The default

    if [[ ${is_auto_install} == "0" ]]; then
      print_title "Disk Encryption"
      print_title_info "Should the disks being used be encrypted?"
      local yes_no=('Yes' 'No')
      local option
      select option in "${yes_no[@]}"; do
        if contains_element "${option}" "${yes_no[@]}"; then
          break
        else
          invalid_option
        fi
      done
      option=$(echo "${option}" | tr "[:upper:]" "[:lower:]")

      case "${option}" in
        yes)
          ENCRYPT_DISKS=1
          ;;

        no)
          ENCRYPT_DISKS=0
          ;;

        *)
          # Default to encrypt disks, more secure.  No need for an error here.
          ENCRYPT_DISKS=1
          ;;
      esac
    fi
  fi

  write_log "Should disks be encrypted: ${ENCRYPT_DISKS}"
}

ask_for_disk_password() {
  write_log "In ask for disk password."

  if [[ ${ENCRYPT_DISKS} == 0 ]]; then
    print_info "Skipping disk password."
    return
  fi

  if [[ -n ${AUTO_DISK_PWD:-} ]]; then
    DISK_PWD=${AUTO_DISK_PWD}
  else
    DISK_PWD="file" # The default

    if [[ ${is_auto_install} == "0" ]]; then
      print_title "Disk Passphrase"
      print_title_info "Enter a passphrase to use for the disk encryption.  NOTE: You can enter a special value of 'file' which will use a randomly generated file placed in the boot location to automatically unlock the disk on boot.  This option is best used for automated environments where a password entry for boot would be inconvenient yet encrypting the disks is still desired.  It also allows changing the encryption key setup later on after the machine is bootstrapped."

      local was_set=0

      blank_line
      while [[ ${was_set} == 0 ]]; do
        local pwd1=""
        local pwd2=""
        read -srp "Disk passphrase: " pwd1
        echo -e ""
        read -srp "Once again: " pwd2

        if [[ "${pwd1}" == "${pwd2}" ]]; then
          DISK_PWD="${pwd1}"
          was_set=1
        else
          blank_line
          print_warning "They did not match... try again."
        fi
      done
    fi
  fi

  write_log_password "Disk passphrase: '${DISK_PWD}'"
}

ask_should_enable_root() {
  write_log "In ask should enable root."

  if [[ -n ${AUTO_ROOT_DISABLED:-} ]]; then
    local input
    input=$(echo "${AUTO_ROOT_DISABLED}" | tr "[:upper:]" "[:lower:]")
    if [[ ${input} == "no" || ${input} == "false" || ${input} == "0" ]]; then
      ROOT_DISABLED=0
    else
      ROOT_DISABLED=1
    fi
  else
    ROOT_DISABLED=1 # The default

    if [[ ${is_auto_install} == "0" ]]; then
      print_title "Disable Root Account"
      print_title_info "Should the root account be disabled?"
      local yes_no=('Yes' 'No')
      local option
      select option in "${yes_no[@]}"; do
        if contains_element "${option}" "${yes_no[@]}"; then
          break
        else
          invalid_option
        fi
      done
      option=$(echo "${option}" | tr "[:upper:]" "[:lower:]")

      case "${option}" in
        yes)
          ROOT_DISABLED=1
          ;;

        no)
          ROOT_DISABLED=0
          ;;

        *)
          # Default is to disable root, more secure.  No need for an error here.
          ROOT_DISABLED=1
          ;;
      esac
    fi
  fi

  write_log "Should root be disabled: ${ROOT_DISABLED}"
}

ask_for_root_password() {
  write_log "In ask for root password."

  if [[ ${ROOT_DISABLED} == 1 ]]; then
    print_info "Skipping root password."
    return
  fi

  if [[ -n ${AUTO_ROOT_PWD:-} ]]; then
    ROOT_PWD=${AUTO_ROOT_PWD}
  else
    ROOT_PWD=${INSTALL_OS} # The Default

    if [[ ${is_auto_install} == "0" ]]; then
      print_title "Root Password"
      print_title_info "Enter a password for root.  You can enter nothing to accept the default '${INSTALL_OS}'."

      local was_set=0

      blank_line
      while [[ ${was_set} == 0 ]]; do
        local pwd1=""
        local pwd2=""
        read -srp "Password: " pwd1
        echo -e ""
        read -srp "Once again: " pwd2

        if [[ "${pwd1}" == "${pwd2}" ]]; then
          ROOT_PWD="${pwd1}"
          if [[ ${ROOT_PWD} == "" ]]; then
            ROOT_PWD=${INSTALL_OS}
          fi

          was_set=1
        else
          blank_line
          print_warning "They did not match... try again."
        fi
      done
    fi
  fi

  write_log_password "Root password: ${ROOT_PWD}"
}

ask_should_create_user() {
  write_log "In ask should create user."

  if [[ ${ROOT_DISABLED} == 1 ]]; then
    print_info "Root user disabled, skipping prompt because a user MUST be created."
    CREATE_USER=1
    return
  fi

  if [[ -n ${AUTO_CREATE_USER:-} ]]; then
    local input
    input=$(echo "${AUTO_CREATE_USER}" | tr "[:upper:]" "[:lower:]")
    if [[ ${input} == "no" || ${input} == "false" || ${input} == "0" ]]; then
      CREATE_USER=0
    else
      CREATE_USER=1
    fi
  else
    CREATE_USER=1 # The default

    if [[ ${is_auto_install} == "0" ]]; then
      print_title "Create User Account"
      print_title_info "Should a user account be created?"
      local yes_no=('Yes' 'No')
      local option
      select option in "${yes_no[@]}"; do
        if contains_element "${option}" "${yes_no[@]}"; then
          break
        else
          invalid_option
        fi
      done
      option=$(echo "${option}" | tr "[:upper:]" "[:lower:]")

      case "${option}" in
        yes)
          CREATE_USER=1
          ;;

        no)
          CREATE_USER=0
          ;;

        *)
          # Default is to create a user.  No need for an error here.
          CREATE_USER=1
          ;;
      esac
    fi
  fi

  write_log "Should a user be created: ${CREATE_USER}"
}

ask_for_user_name() {
  write_log "In ask for username."

  if [[ ${CREATE_USER} == 0 ]]; then
    print_info "Skipping username prompt as user creation was disabled."
    return
  fi

  if [[ -n ${AUTO_USERNAME:-} ]]; then
    USERNAME=${AUTO_USERNAME}
  else
    USERNAME=${INSTALL_OS}  # The default

    if [[ ${is_auto_install} == "0" ]]; then
      print_title "User"
      print_title_info "Enter a username to create."
      local input=""
      read -rp "Username [${USERNAME}]: " input
      if [[ ${input} != "" ]]; then
        USERNAME=${input}
      fi
    fi
  fi

  write_log "Username To Create: ${USERNAME}"
}

ask_for_user_password() {
  write_log "In ask for user password."

  if [[ ${CREATE_USER} == 0 ]]; then
    print_info "Skipping user password prompt as user creation was disabled."
    return
  fi

  if [[ -n ${AUTO_USER_PWD:-} ]]; then
    USER_PWD=${AUTO_USER_PWD}
  else
    USER_PWD=${INSTALL_OS} # The Default

    if [[ ${is_auto_install} == "0" ]]; then
      print_title "User Password"
      print_title_info "Enter a password for the user '${USERNAME}'.  You can enter nothing to accept the default '${INSTALL_OS}'."

      local was_set=0

      blank_line
      while [[ ${was_set} == 0 ]]; do
        local pwd1=""
        local pwd2=""
        read -srp "Password: " pwd1
        echo -e ""
        read -srp "Once again: " pwd2

        if [[ "${pwd1}" == "${pwd2}" ]]; then
          USER_PWD="${pwd1}"
          if [[ ${USER_PWD} == "" ]]; then
            USER_PWD=${INSTALL_OS}
          fi

          was_set=1
        else
          blank_line
          print_warning "They did not match... try again."
        fi
      done
    fi
  fi

  write_log_password "User password: ${USER_PWD}"
}

print_summary() {
  print_title "Install Summary"
  print_title_info "Below is a summary of your selections and any auto-detected system information.  If anything is wrong cancel out now with Ctrl-C.  If you continue, the installation will begin and there will be no more input required."
  print_line
  if [[ ${UEFI} == 1 ]]; then
    print_status "The machine architecture is ${SYS_ARCH} and UEFI has been found."
  else
    print_status "The machine architecture is ${SYS_ARCH} and a BIOS has been found."
  fi

  blank_line

  print_status "The keymap to use is '${KEYMAP}'."

  print_status "The distribution to install is '${INSTALL_OS}', '${INSTALL_EDITION}' edition."

  if [[ ${USE_BACKPORTS} == 1 ]]; then
    print_status "Backports and\or HWE Kernels will be installed."
  else
    print_status "Backports and\or HWE Kernels have been skipped."
  fi

  if [[ ${SUPPORT_HIBERNATION} == 1 ]]; then
    print_status "Hibernation will be supported."
  else
    print_status "Hibernation will NOT be supported."
  fi

  print_status "The hostname selected is '${HOSTNAME}'."
  if [[ ${DOMAIN} != "" ]]; then
    print_status "The domain selected is '${DOMAIN}'."
  fi

  print_status "The timezone to use is '${TIMEZONE}'."

  blank_line
  if [[ ${MULTI_DISK_SYSTEM} == 0 ]]; then
    print_status "This is a single disk system so installation has automatically selected '${MAIN_DISK}' as the installation disk."
  else
    if [[ ${SECOND_DISK_SELECTION} == "ignore" ]]; then
      print_status "This is a multi-disk system, but other disks have been ignored."
    else
      print_status "This is a multi-disk system."
    fi

    print_status "The main disk selection method was '${MAIN_DISK_SELECTION}' and the disk chosen was '${MAIN_DISK}'."

    if [[ ${SECOND_DISK_SELECTION} != "ignore" ]]; then
      print_status "The second disk selection method was '${SECOND_DISK_SELECTION}' and the disk chosen was '${SECOND_DISK}'."
    fi
  fi
  if [[ ${ENCRYPT_DISKS} == 1 ]]; then
    print_status "The disks will be encrypted."
  else
    print_status "The disks will NOT be encrypted."
  fi

  blank_line
  if [[ ${ROOT_DISABLED} == 1 ]]; then
    print_status "The root account will be disabled."
  else
    print_status "The root account will be activated."
  fi

  if [[ ${CREATE_USER} == 1 ]]; then
    print_status "User '${USERNAME}' will be created and granted sudo permissions."
  else
    print_status "User creation was disabled."
  fi

  blank_line
  pause_output
}

### END: Primpts & User Interaction

echo -e "ERROR: This script is not yet implemented."
exit 1
