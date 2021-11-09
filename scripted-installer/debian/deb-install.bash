#!/usr/bin/env bash
# shellcheck disable=SC2181
# Author: Brennan Fee
# Version: 0.02  2021-11-05
#
# URL to install: bash <(curl -fsSL https://<path tbd>)
#
# This script installs Debian/Ubuntu the "Arch" way.  In order to have more fine-grained control it completely bypasses the Debian or Ubuntu installers and does all the setup here.  You must run the Debian (or Ubuntu) live "server" ISOs (which one shouldn't matter), truthfully it doesn't matter which one as you can install Ubuntu using the Debian ISO and Debian using the Ubuntu ISO.
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

### Start: Constants & Global Variables

# Should only be on during testing.  Primarly this turns on the output of passwords.
IS_DEBUG=1

# Text modifiers
Bold="\033[1m"
Reset="\033[0m"

# Colors
Red="\033[31m"
Green="\033[32m"
Yellow="\033[33m"

# Paths
WORKING_DIR=$(pwd)
LOG="${WORKING_DIR}/install.log"
[[ -f ${LOG} ]] && rm -f "${LOG}"
{
  echo "Start log..."
  echo "Date: $(date -Is)"
  echo "------------"
} >> "${LOG}"

# Auto detected flags and variables
SYS_ARCH=$(uname -m) # Architecture (x86_64)
DPKG_ARCH=$(dpkg --print-architecture) # Something like amd64, arm64
UEFI=0
XPINGS=0 # CONNECTION CHECK

# This is not to be confused with the OS we are going to install, this is the OS that was booted to perform the installs.  This script only supports Debian and Ubuntu Live Server installers images.
INSTALLER_DISTRO=$(lsb_release -i -s | tr "[:upper:]" "[:lower:]")

SUPPORTED_OS_DISPLAY=('Debian' 'Ubuntu')
SUPPORTED_OS=('debian' 'ubuntu')

### End: Constants & Global Variables

### Start: Options & User Overrideable Parameters

# All options can be passed in as environment variables to override the defaults.  This works whether using a fully automatic install or not.  The overridable values all begin with "AUTO_" to indicate that they are "automatic" incoming variables.  Any values that are overriden will skip those questions to the user.

# Is this a "fully" automated install?  An automated install will suppress all prompts and select or use default values or the passed in overrides.  Technically, this is the only environment variable needed to trigger a silent install (which will use all the defaults).
AUTO_INSTALL="${AUTO_INSTALL:-0}"

# The keymap to use.
AUTO_KEYMAP="${AUTO_KEYMAP:-}"

# The OS to install, default is debian, alternative "ubuntu"
AUTO_INSTALL_OS="${AUTO_INSTALL_OS:-}"

# The distro edition (sometimes called codename) to install.  For debian this is things like 'stable', 'bullesye', etc.  And for Ubuntu it is always the codename 'focal', 'impish', etc.  For anything else that is "debian" like this is what should be placed into the APT sources.list.
AUTO_INSTALL_EDITION="${AUTO_INSTALL_EDITION:-}"

# For Debian, this will install the backports repo (and any kernel from it); while for Ubuntu this will install any available HWE kernel in the LTS editions.  The default is to install updated kernels.
AUTO_USE_BACKPORTS_OR_HWE="${AUTO_USE_BACKPORTS_OR_HWE:-}"

# Whether or not the swap size should be large enough to support hibernation.  The default is to NOT do this as it can needlessly consume a lot of disk space.
AUTO_SUPPORT_HIBERNATION="${AUTO_SUPPORT_HIBERNATION:-}"

# The default hostname of the machine being created
AUTO_HOSTNAME="${AUTO_HOSTNAME:-}"

# The domain for the machine being created.
AUTO_DOMAIN="${AUTO_DOMAIN:-}"

# The time zone for the machine being created.
AUTO_TIMEZONE="${AUTO_TIMEZONE:-}"

# The main disk to install the OS to.  It can be a device (like /dev/sda) or a size match like "smallest" or "largest"
AUTO_MAIN_DISK="${AUTO_MAIN_DISK:-}"

# What to do if with a second disk on the machine.  This is ignored if only one disk is found.  But in cases where two or more disks are found this indicates what happens.  A value of "ignore" will ignore the second disk and install as though the machine had only one disk.  A device (like /dev/sdb) can be passed which will select that as the second disk, ignoring anything else.  It can NOT refer to the main disk even if the main disk was selected automatically.  Lastly, a size selector can be passed like "smallest" or "largest".  In the event that the main disk was selected by size, this would be the in essence the next smallest or next largest disk.
AUTO_SECOND_DISK="${AUTO_SECOND_DISK:-}"

# Whether the volume(s) created should be encrypted.  Valid values are "yes" or "no".  Blank will prompt the user, or in an automated install will, by default, encrypt the disks.
AUTO_ENCRYPT_DISKS="${AUTO_ENCRYPT_DISKS:-}"

# The password to use for the encrypted volumes.  A special value of "file" can be passed which will create a disk file in the bios/efi location that will auto-decrypt on boot.  This is obviously not secure but can be used in automated scenario's such that later encryption could be disabled or different key or unlock mechanisms could be put in place.
AUTO_DISK_PWD="${AUTO_DISK_PWD:-}"

# Whether root should be disabled.  Valid values are "yes" or "no".  Blank will prompt the user, or in an automated install will, by default, disable the root account.
AUTO_ROOT_DISABLED="${AUTO_ROOT_DISABLED:-}"

# If root is enabled, what the root password should be.  This can be a text password or a crypted password.
AUTO_ROOT_PWD="${AUTO_ROOT_PWD:-}"

# Whether to create a user.  If the root user is disabled with the AUTO_ROOT_DISABLED option, this value will be ignored as in that case a user MUST be created.
AUTO_CREATE_USER="${AUTO_CREATE_USER:-}"

# The user to create, defaults to a username and password that matches the installed OS (debian or ubuntu).  The password can be a text password or a crypted password.
AUTO_USERNAME="${AUTO_USERNAME:-}"
AUTO_USER_PWD="${AUTO_USER_PWD:-}"

### END: Options & User Overrideable Parameters

### START: Params after prompt/read/parsing

INSTALL_OS="debian"
INSTALL_EDITION="stable"
USE_BACKPORTS=0
SUPPORT_HIBERNATION=0
KEYMAP="us"
HOSTNAME=""
DOMAIN=""
TIMEZONE="America/Chicago"
MAIN_DISK_SELECTION="smallest"
SECOND_DISK_SELECTION="largest"
ENCRYPT_DISKS=1
DISK_PWD="file"
ROOT_DISABLED=1
ROOT_PWD="${INSTALL_OS}"
CREATE_USER=1
USERNAME="${INSTALL_OS}"
USER_PWD="${INSTALL_OS}"

MULTI_DISK_SYSTEM=0
MAIN_DISK=""
SECOND_DISK=""

### END: Params after prompt/read/parsing

### START: Print & Log Functions

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

pause_function() {
  print_line
  if [[ ${is_auto_install} == "0" ]]; then
    read -re -sn 1 -p "Press enter to continue..."
  fi
}

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

invalid_option() {
  print_line
  print_warning "Invalid option. Try again."
}

invalid_option_error() {
  print_line
  error_msg "Invalid option. Try again."
}

### END: Print & Log Functions

### START: Helper Functions

determine_is_auto_install() {
  if [[ -n ${AUTO_INSTALL:-} ]]; then
    local input
    input=$(echo "${AUTO_INSTALL}" | tr "[:upper:]" "[:lower:]")
    if [[ ${input} == "yes" || ${input} == "true" || ${input} == "1" ]]; then
      echo "1"
    else
      echo "0"
    fi
  else
    echo "0"
  fi
}
is_auto_install=$(determine_is_auto_install)

should_use_second_disk() {
  if [[ ${MULTI_DISK_SYSTEM} == 1 && ${SECOND_DISK} != "ignore" ]]; then
    echo "1"
  else
    echo "0"
  fi
}
use_second_disk=$(should_use_second_disk)

contains_element() {
  #check if an element exist in a string
  for e in "${@:2}"; do [[ ${e} == "$1" ]] && break; done
}

chroot_install() {
  write_log "Installing to target: '$*'"
  DEBIAN_FRONTEND=noninteractive arch-chroot /mnt apt-get -y -q --no-install-recommends install "$@"
}

### END: Helper Functions

### START: Verification Functions

check_root() {
  print_info "Checking root permissions..."

  if [[ "$(id -u)" != "0" ]]; then
    error_msg "ERROR! You must execute the script as the 'root' user."
  fi
}

check_linux_distro() {
  print_info "Checking installer distribution..."
  write_log "Installer distro detected: ${INSTALLER_DISTRO}"

  if [[ ${INSTALLER_DISTRO} != "debian" && ${INSTALLER_DISTRO} != "ubuntu" ]]; then
    error_msg "ERROR! You must execute the script on Debian or Ubuntu Live Image."
  fi
}

detect_if_eufi() {
  print_info "Detecting UEFI..."

  if [[ "$(cat /sys/class/dmi/id/sys_vendor)" == 'Apple Inc.' ]] || [[ "$(cat /sys/class/dmi/id/sys_vendor)" == 'Apple Computer, Inc.' ]]; then
    modprobe -r -q efivars || true # if MAC
  else
    modprobe -q efivarfs # all others
  fi

  if [[ -d "/sys/firmware/efi/" ]]; then
    ## Mount efivarfs if it is not already mounted
    # shellcheck disable=SC2143
    if [[ -z $(mount | grep /sys/firmware/efi/efivars) ]]; then
      mount -t efivarfs efivarfs /sys/firmware/efi/efivars
    fi
    UEFI=1
  else
    UEFI=0
  fi
}

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
      print_warning "Can't establish connection. exiting..."
      exit 1
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

ask_should_support_hibernation() {
  write_log "In ask should support hibernation."

  if [[ -n ${AUTO_SUPPORT_HIBERNATION:-} ]]; then
    local input
    input=$(echo "${AUTO_SUPPORT_HIBERNATION}" | tr "[:upper:]" "[:lower:]")
    if [[ ${input} == "yes" || ${input} == "true" || ${input} == "1" ]]; then
      SUPPORT_HIBERNATION=1
    else
      SUPPORT_HIBERNATION=0
    fi
  else
    SUPPORT_HIBERNATION=0 # The default

    if [[ ${is_auto_install} == "0" ]]; then
      print_title "Should hibernation be supported"
      print_title_info "Should hibernation be supported on this machine?"
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
          SUPPORT_HIBERNATION=1
          ;;

        no)
          SUPPORT_HIBERNATION=0
          ;;

        *)
          SUPPORT_HIBERNATION=0
          ;;
      esac
    fi
  fi

  write_log "Should support hibernation: ${SUPPORT_HIBERNATION}"
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
  pause_function
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

### END: Primpts & User Interaction

### START: Preparation Functions

install_prereqs() {
  print_info "Installing prerequisites"
  DEBIAN_FRONTEND=noninteractive apt-get -y -q update || true
  DEBIAN_FRONTEND=noninteractive apt-get -y -q full-upgrade || true
  DEBIAN_FRONTEND=noninteractive apt-get -y -q autoremove || true

  install_debian_prereqs

  install_ubuntu_prereqs

  # Things they both need
  DEBIAN_FRONTEND=noninteractive apt-get -y -q install vim-nox debootstrap arch-install-scripts parted gdisk bc

  DEBIAN_FRONTEND=noninteractive apt-get -y -q autoremove || true
}

install_debian_prereqs() {
  if [[ ${INSTALLER_DISTRO} == "debian" ]]; then
    DEBIAN_FRONTEND=noninteractive apt-get -y -q install console-data
  fi
}

install_ubuntu_prereqs() {
  if [[ ${INSTALLER_DISTRO} == "ubuntu" ]]; then
    write_log "No Ubuntu specific prereqs at this time."
  fi
}

### END: Preparation Functions

### START: Disk And Partition Functions

unmount_partitions() {
  print_info "Unmounting partitions"
  local mounted_partitions
  mapfile -t mounted_partitions < <(lsblk --output MOUNTPOINT | grep "^/mnt" | sort -r)

  swapoff -a
  for i in "${mounted_partitions[@]}"; do
    umount "${i}"
  done
}

wipe_disks() {
  print_info "Wiping disks"

  print_info "    Wiping main disk partitions"
  wipefs --all --force "${MAIN_DISK}*" 2>/dev/null || true
  wipefs --all --force "${MAIN_DISK}" || true

  dd if=/dev/zero of="${MAIN_DISK}" bs=512 count=100 conv=notrunc
  dd if=/dev/zero of="${MAIN_DISK}" bs=512 seek=$(( $(blockdev --getsz "${MAIN_DISK}") - 100 )) count=100 conv=notrunc

  if [[ ${use_second_disk} == "1" ]]; then
    print_info "    Wiping second disk partitions"
    wipefs --all --force "${SECOND_DISK}*" 2>/dev/null || true
    wipefs --all --force "${SECOND_DISK}" || true

    dd if=/dev/zero of="${SECOND_DISK}" bs=512 count=100 conv=notrunc
    dd if=/dev/zero of="${SECOND_DISK}" bs=512 seek=$(( $(blockdev --getsz "${SECOND_DISK}") - 100 )) count=100 conv=notrunc
  fi

  partprobe 2>/dev/null || true
}

create_main_partitions() {
  print_info "Creating main partitions"

  print_status "    Creating partition table"
  parted --script -a optimal "${MAIN_DISK}" mklabel gpt

  # Note: In this script the first two partitions are always "system" partitions while
  # the third partition (such as /dev/sda3) will ALWAYS be the main data partition.

  print_status "    Boot partitions"
  if [[ ${UEFI} == 1 ]]; then
    # EFI partition (512mb)
    parted --script -a optimal "${MAIN_DISK}" mkpart "esp" fat32 0% 512MB
    parted --script -a optimal "${MAIN_DISK}" set 1 esp on
    # Boot partition (1gb)
    parted --script -a optimal "${MAIN_DISK}" mkpart "boot" ext4 512MB 1536MB

    print_status "    Main Partition"
    parted --script -a optimal "${MAIN_DISK}" mkpart "os" ext4 1536MB 100%
  else
    # BIOS Grub partition (1mb)
    parted --script -a optimal "${MAIN_DISK}" mkpart "grub" fat32 0% 1MB
    parted --script -a optimal "${MAIN_DISK}" set 1 bios_grub on
    # Boot partition (1gb)
    parted --script -a optimal "${MAIN_DISK}" mkpart "boot" ext4 1MB 1025MB
    parted --script -a optimal "${MAIN_DISK}" set 2 boot on

    print_status "    Main Partition"
    parted --script -a optimal "${MAIN_DISK}" mkpart "os" ext4 1025MB 100%
  fi

  partprobe 2>/dev/null || true
}

create_secondary_partitions() {
  if [[ ${use_second_disk} == "1" ]]; then
    print_info "Creating secondary disk partitions"

    print_status "    Creating partition table"
    parted --script -a optimal "${SECOND_DISK}" mklabel gpt

    print_status "    Secondary Partition"
    parted --script -a optimal "${SECOND_DISK}" mkpart "data" xfs 0% 100%
    if [[ ${ENCRYPT_DISKS} == 0 ]]; then
      parted --script -a optimal "${SECOND_DISK}" set 1 lvm on
    fi
  fi

  partprobe 2>/dev/null || true
}

# setup_encryption() {
#   if [[ ${ENCRYPT_DISKS} == 1 ]]; then
#     print_info "Setting up encryption"

#     local main_drive=""
#     local main_sector_size=""

#     # shellcheck disable=SC2001
#     main_drive=$(echo "${MAIN_DISK}" | sed -e 's|^/dev/||')
#     main_sector_size=$(cat /sys/block/"${main_drive}"/queue/physical_block_size)

#     echo "test" | cryptsetup luksFormat --type luks2 --sector-size "${main_sector_size}" "${MAIN_DISK}3" -

#     if [[ ${use_second_disk} == "1" ]]; then
#       local second_drive=""
#       local second_sector_size=""

#       # shellcheck disable=SC2001
#       second_drive=$(echo "${SECOND_DISK}" | sed -e 's|^/dev/||')
#       second_sector_size=$(cat /sys/block/"${second_drive}"/queue/physical_block_size)

#       echo "test" | cryptsetup luksFormat --type luks2 --sector-size "${second_sector_size}" "${SECOND_DISK}1" -
#     fi
#   fi
# }

setup_encryption() {
  if [[ ${ENCRYPT_DISKS} == 1 ]]; then
    print_info "Setting up encryption"

    echo -n "test" | cryptsetup -s 512 --iter-time 5000 luksFormat --type luks2 "${MAIN_DISK}3" -
    echo -n "test" | cryptsetup open "${MAIN_DISK}3" cryptroot --key-file -

    if [[ ${use_second_disk} == "1" ]]; then
      echo -n "test" | cryptsetup -s 512 --iter-time 5000 luksFormat --type luks2 "${SECOND_DISK}1" -
      echo -n "test" | cryptsetup open "${SECOND_DISK}1" cryptdata --key-file -
    fi
  fi
}

setup_lvm() {
  if [[ ${use_second_disk} == "1" ]]; then
    print_info "Setting up LVM"

    local pv_volume
    if [[ ${ENCRYPT_DISKS} == 1 ]]; then
      pv_volume "/dev/mapper/cryptdata"
    else
      pv_volume "${SECOND_DISK}1"
    fi

    pvcreate "${pv_volume}"
    vgcreate "vg_data" "${pv_volume}"

    lvcreate -l 50%VG "vg_data" -n lv_home
    lvcreate -l 30%VG "vg_data" -n lv_data
  fi
}

format_partitions() {
  print_info "Formatting partitions"

  if [[ ${UEFI} == 1 ]]; then
    # Format the EFI partition
    mkfs.vfat -n EFI "${MAIN_DISK}1"
  fi

  # Now boot...
  mkfs.ext4 "${MAIN_DISK}2"

  # Now root...
  local root_volume
  if [[ ${ENCRYPT_DISKS} == 1 ]]; then
    root_volume="/dev/mapper/cryptroot"
  else
    root_volume="${MAIN_DISK}3"
  fi

  mkfs.ext4 "${root_volume}"

  if [[ ${use_second_disk} == "1" ]]; then
    mkfs.xfs "/dev/mapper/vg_data-lv_home"
    mkfs.xfs "/dev/mapper/vg_data-lv_data"
  fi
}

mount_partitions() {
  print_info "Mounting partitions"

  # First root
  local root_volume
  if [[ ${ENCRYPT_DISKS} == 1 ]]; then
    root_volume="/dev/mapper/cryptroot"
  else
    root_volume="${MAIN_DISK}3"
  fi
  mount -t ext4 -o errors=remount-ro "${root_volume}" /mnt

  # Now boot
  mkdir /mnt/boot
  mount -t ext4 "${MAIN_DISK}2" /mnt/boot

  if [[ ${UEFI} == 1 ]]; then
    # And EFI
    mkdir /mnt/boot/efi
    mount -t vfat "${MAIN_DISK}1" /mnt/boot/efi
  fi

  if [[ ${use_second_disk} == "1" ]]; then
    mkdir /mnt/home
    mount -t xfs "/dev/mapper/vg_data-lv_home" /mnt/home

    mkdir /mnt/data
    mount -t xfs "/dev/mapper/vg_data-lv_data" /mnt/data
  else
    # Just make a data directory on the root
    mkdir /mnt/data
  fi
}

### END: Disk And Partition Functions

### START: Install System

install_base_system() {
  print_info "Installing base system"

  case "${INSTALL_OS}" in
    debian)
      install_base_system_debian
      ;;

    ubuntu)
      install_base_system_ubuntu
      ;;

    *)
      error_msg "ERROR! OS to install not supported: '${INSTALL_OS}'"
      ;;
    esac
}

install_base_system_debian() {
  print_status "    Installing Debian"

  # Bootstrap
  debootstrap --arch "${DPKG_ARCH}" "${INSTALL_EDITION}" /mnt "http://deb.debian.org/debian"

  # Configure apt for the rest of the installations
  configure_apt_debian

  # Updates, just in case
  arch-chroot /mnt apt-get update
  arch-chroot /mnt apt-get upgrade -y --no-install-recommends

  # Standard server setup
  arch-chroot /mnt tasksel --new-install install standard
  arch-chroot /mnt locale-gen en_US.UTF-8

  # Kernel & Firmware
  if [[ ${USE_BACKPORTS} == "1" && ${INSTALL_EDITION} != "testing" ]]; then
    local edition=${INSTALL_EDITION}
    if [[ ${edition} == "stable" ]]; then
      # Can't use "stable" for backports, must convert to the codename
      edition=$(lsb_release -s -c)
    fi

    arch-chroot /mnt apt-get -y --no-install-recommends install -t "${edition}-backports" "linux-image-${DPKG_ARCH}" "linux-headers-${DPKG_ARCH}" firmware-linux
  else
    chroot_install "linux-image-${DPKG_ARCH}" "linux-headers-${DPKG_ARCH}" firmware-linux
  fi
}

install_base_system_ubuntu() {
  print_status "    Installing Ubuntu"

  # Bootstrap
  debootstrap --arch "${DPKG_ARCH}" "${INSTALL_EDITION}" /mnt "http://us.archive.ubuntu.com/ubuntu"

  # Configure apt for the rest of the installations
  configure_apt_ubuntu

  # Updates, just in case
  arch-chroot /mnt apt-get update && apt-get upgrade -y --no-install-recommends

  chroot_install language-pack-en ubuntu-minimal
  arch-chroot /mnt locale-gen en_US.UTF-8

  local release_ver
  release_ver=$(arch-chroot /mnt lsb_release -r -s)
  write_log "DEBUG>>> ubuntu release: ${release_ver}"
  # Kernel & Firmware (using backports means HWE kernel)
  #if [[ ${USE_BACKPORTS} == "1" ]]; then
  #else
  #fi

  # For now, just the standard kernel
  chroot_install linux-generic linux-headers-generic linux-firmware
}

install_bootloader() {
  print_info "Installing bootloader"

  if [[ ${UEFI} == 1 ]]; then
    chroot_install os-prober grub-efi-amd64 grub-efi-amd64-signed

    arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=debian --recheck --no-nvram "${MAIN_DISK}"

    arch-chroot /mnt update-grub
  else
    print_warning "BIOS support is EXPERIMENTAL and not well tested"

    chroot_install os-prober grub-pc

    arch-chroot /mnt grub-install "${MAIN_DISK}"

    arch-chroot /mnt update-grub
  fi
}

install_virtualization() {
  if [[ $(systemd-detect-virt) == "oracle" ]]; then
    # In virtualbox
    print_info "Installing VirtualBox Additions"

    # Install the prerequs
    chroot_install build-essential dkms

    # Download the iso
    /usr/bin/wget --output-document "/tmp/LATEST-STABLE.TXT" https://download.virtualbox.org/virtualbox/LATEST-STABLE.TXT

    vb_version=$(cat "/tmp/LATEST-STABLE.TXT")
    rm "/tmp/LATEST-STABLE.TXT"

    vb_url="https://download.virtualbox.org/virtualbox/${vb_version}/VBoxGuestAdditions_${vb_version}.iso"
    /usr/bin/wget --output-document "/tmp/VBoxGuestAdditions.iso" "${vb_url}"

    # Mount the ISO and run the install
    mkdir -p /mnt/media/vb-additions
    mount -t iso9660 -o loop,ro /tmp/VBoxGuestAdditions.iso /mnt/media/vb-additions
    arch-chroot /mnt /media/vb-additions/VBoxLinuxAdditions.run --nox11 || true
    umount /mnt/media/vb-additions
    rmdir /mnt/media/vb-additions
    rm /tmp/VBoxGuestAdditions.iso
  fi
}

### END: Install System

### START: System Configuration

configure_locale() {
  print_info "Configuring locale"

  sed -i 's/# en_US.UTF-8/en_US.UTF-8/' /mnt/etc/locale.gen
  sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /mnt/etc/locale.gen
  arch-chroot /mnt locale-gen

  arch-chroot /mnt update-locale --reset LANG=en_US.UTF-8 LANGUAGE=en_US:en
}

configure_apt_debian() {
  print_info "Configuring APT (Debian)"

  # Backup the one originally installed
  cp /mnt/etc/apt/sources.list /mnt/etc/apt/sources.list.bootstrapped

  # Write out sources
  cat <<- 'EOF' > /mnt/etc/apt/sources.list
deb http://deb.debian.org/debian EDITION main contrib non-free

deb http://deb.debian.org/debian-security EDITION-security main contrib non-free

deb http://deb.debian.org/debian EDITION-updates main contrib non-free
EOF

  sed -i "s|EDITION|${INSTALL_EDITION}|g" /mnt/etc/apt/sources.list

  cat <<- 'EOF' > /mnt/etc/apt/apt.conf.d/80no-recommends
APT::Install-Suggests "0";
APT::Install-Recommends "0";
EOF

  if [[ ${USE_BACKPORTS} == "1" && ${INSTALL_EDITION} != "testing" ]]; then
    local edition=${INSTALL_EDITION}
    if [[ ${edition} == "stable" ]]; then
      # Can't use "stable" for backports, must convert to the codename
      edition=$(lsb_release -s -c)
    fi

    cat <<- 'EOF' > /mnt/etc/apt/sources.list.d/debian-backports.list
deb http://deb.debian.org/debian EDITION-backports main contrib non-free
EOF

    sed -i "s|EDITION|${edition}|g" /mnt/etc/apt/sources.list.d/debian-backports.list
  fi

  arch-chroot /mnt apt-get update
}

configure_apt_ubuntu() {
  print_info "Configuring APT (Debian)"

  # Backup the one originally installed
  cp /mnt/etc/apt/sources.list /mnt/etc/apt/sources.list.bootstrapped

  # Write out sources
  cat <<- 'EOF' > /mnt/etc/apt/sources.list
deb http://us.archive.ubuntu.com/ubuntu EDITION main restricted universe multiverse

deb http://us.archive.ubuntu.com/ubuntu EDITION-updates main restricted universe multiverse

deb http://us.archive.ubuntu.com/ubuntu EDITION-backports main restricted universe multiverse

deb http://us.archive.ubuntu.com/ubuntu EDITION-security main restricted universe multiverse
EOF

  sed -i "s|EDITION|${INSTALL_EDITION}|g" /mnt/etc/apt/sources.list

  cat <<- 'EOF' > /mnt/etc/apt/apt.conf.d/80no-recommends
APT::Install-Suggests "0";
APT::Install-Recommends "0";
EOF

  arch-chroot /mnt apt-get update
}

configure_keymap() {
  print_info "Configure keymap"

  chroot_install console-setup

  echo "KEYMAP=${KEYMAP}" > /mnt/etc/vconsole.conf
  echo "FONT=Lat7-Terminus20x10" >> /mnt/etc/vconsole.conf
  # Others small-ish: Lat7-Terminus14,Lat7-Terminus16
  # Others large-ish: Lat7-Terminus20x10,Lat7-Terminus22x11,Lat7-Terminus24x12,Lat7-Terminus28x14,
}

configure_fstab() {
  print_info "Write fstab"

  genfstab -t UUID -p /mnt > /mnt/etc/fstab
}

configure_hostname() {
  print_info "Setup hostname"

  echo "${HOSTNAME}" > /mnt/etc/hostname

  local the_line
  if [[ ${DOMAIN} == "" ]]; then
    the_line="127.0.1.1 ${HOSTNAME}"
  else
    the_line="127.0.1.1 ${HOSTNAME}.${DOMAIN} ${HOSTNAME}"
  fi

  if grep -q '^127.0.1.1[[:blank:]]' /mnt/etc/hosts; then
    # Update the line
    sed -i "/^127.0.1.1[[:blank:]]/ s/.*/${the_line}/g" /mnt/etc/hosts
  else
    # Add the line
    echo -E "${the_line}" >> /mnt/etc/hosts
  fi
}

configure_timezone() {
  print_info "Configuring timezone"

  # First, the hardware clock
  arch-chroot /mnt hwclock --systohc --utc --update-drift

  # Configure the timezone
  arch-chroot /mnt timedatectl set-local-rtc 0
  arch-chroot /mnt timedatectl set-timezone "${TIMEZONE}"
}

configure_initramfs() {
  print_info "Configuring initramfs"

  # Make sure lz4 is installed
  chroot_install lz4

  # Set that as the compression to use
  sed -i '/^COMPRESS=/ s/.*/COMPRESS=lz4/g' /mnt/etc/initramfs-tools/initramfs.conf

  # Run update
  arch-chroot /mnt update-initramfs -u
}

configure_swap() {
  print_info "Configuring swap"

  # NOTE: The default calculat is the sqrt of total ram size with a floor of 2gb.  Generally, this will NOT be enough swap space to support hibernation.  To support hibernation an option is avialble.  In that case the swap space calcualtion is the total size of ram plus the square root of the total ram size.

  # Calculate swap file size
  local avail_ram_kib
  local avail_ram_gb
  local avail_ram_sqrt
  local size

  # Grab the amount of physical ram (in kib)
  avail_ram_kib=$(grep -i '^MemTotal' /proc/meminfo | awk '{print $2}')
  # Convert to GB
  avail_ram_gb=$(echo "scale=6; ${avail_ram_kib}/1048576*1.073741825" | bc)
  # Square root it
  avail_ram_sqrt=$(echo "scale=6; sqrt(${avail_ram_gb})" | bc)
  # Round it
  size=$(printf "%0.f\n" "${avail_ram_sqrt}")

  # If hibernation is to be supported, make the size the available ram + the sqrt value
  if [[ ${SUPPORT_HIBERNATION} == 1 ]]; then
    size=$(echo "scale=6; ${avail_ram_gb}+${avail_ram_sqrt}" | bc)
    # round it
    size=$(printf "%0.f\n" "${size}")
  fi

  # Make sure the minimum is 2gb
  if [[ "${size}" -lt "1" ]]; then
    size="2"
  fi

  # Create a swap file
  fallocate -l "${size}G" /mnt/swapfile
  chmod 600 /mnt/swapfile
  mkswap /mnt/swapfile

  # Remove any previous swap
  sed -i '/ swap /d' /mnt/etc/fstab
  # Now add the swap file
  echo "/swapfile swap swap sw 0 0" >> /mnt/etc/fstab
}

configure_networking() {
  print_info "Configuring networking"

  chroot_install network-manager netplan.io

  cat <<- 'EOF' > /mnt/etc/netplan/01-network-manage-all.yaml
# Let NetworkManager manage all devices on this system
network:
  version: 2
  renderer: NetworkManager
EOF

  arch-chroot /mnt netplan generate
}

### END: System Configuration

### START: Install Applications

install_applications_common() {
  print_info "Installing common applications"

  chroot_install apt-transport-https ca-certificates curl wget gnupg lsb-release build-essential dkms sudo acl git vim-nox python3-dev python3-setuptools python3-wheel python3-keyring python3-venv python3-pip python-is-python3 software-properties-common
}

install_applications_debian() {
  if [[ ${INSTALL_OS} == "debian" ]]; then
    print_info "Installing Debian specific applications"

    chroot_install task-ssh-server
  fi
}

install_applications_ubuntu() {
  if [[ ${INSTALL_OS} == "ubuntu" ]]; then
    print_info "Installing Ubuntu specific applications"

    chroot_install openssh-server openssh-client
  fi
}

### END: Install Applications

### START: User Configuration

setup_root() {
  if [[ ${ROOT_DISABLED} == "0" ]]; then
    print_info "Setting up root"

    # Unlock the root account
    arch-chroot /mnt passwd -u root

    # Check if the password is encrypted
    if echo "${ROOT_PWD}" | grep -q '^\$[[:digit:]]\$.*$'; then
      # Password is encrypted
      arch-chroot /mnt usermod --password "${ROOT_PWD}" root
    else
      # Password is plaintext
      arch-chroot /mnt usermod --password "$(echo "${ROOT_PWD}" | openssl passwd -6 -stdin)" root
    fi

    # If root is the only user, allow login with root through SSH.  Users can of course (and should) change this after initial boot, this just allows a remote connection to start things off.
    if [[ ${CREATE_USER} == "0" ]]; then
      sed -i '/PermitRootLogin / s/.*/PermitRootLogin yes' /mnt/etc/ssh/sshd_config
    fi
  fi
}

setup_user() {
  if [[ ${CREATE_USER} == "1" ]]; then
    print_info "Setting up user"

    arch-chroot /mnt adduser --quiet --group --disabled-password --gecos "${USERNAME}" "${USERNAME}"
    # Check if the password is encrypted
    if echo "${USER_PWD}" | grep -q '^\$[[:digit:]]\$.*$'; then
      # Password is encrypted
      arch-chroot /mnt usermod --password "${USER_PWD}" "${USERNAME}"
    else
      # Password is plaintext
      arch-chroot /mnt usermod --password "$(echo "${USER_PWD}" | openssl passwd -6 -stdin)" "${USERNAME}"
    fi

    # Add the user to the sudo and ssh groups
    arch-chroot /mnt usermod -a -G sudo "${USERNAME}"
    arch-chroot /mnt usermod -a -G ssh "${USERNAME}"

    if [[ $(systemd-detect-virt) == "oracle" ]]; then
      # In virtualbox, add them to the vboxsf group
      arch-chroot /mnt usermod -a -G vboxsf "${USERNAME}"
    fi
  fi
}

### END: User Configuration

### START: Wrapping Up

clean_up() {
  print_info "Cleaning up"

  # Clean apt
  arch-chroot /mnt apt-get clean

  # Trim logs
  find /mnt/var/log -type f -cmin +10 -delete
}

stamp_build() {
  print_info "Stamping build"

  echo "Build Time: $(date -Is)" | sudo tee /mnt/data/build-time.txt
  cp "${LOG}" /mnt/data/deb-install-log.txt
}

show_complete_screen() {
  print_title "INSTALL COMPLETED"
  print_success "After reboot you can configure users, install other software, etc."

  blank_line
}

### END: Wrapping Up

### START: Script sections

welcome_screen() {
  print_title "https://github.com/brennanfee/linux-bootstraps"
  print_title_info "Provision Debian -> Automated script to install my Debian and Ubuntu systems the 'Arch way'."
  print_line
  print_status "Script can be cancelled at any time with CTRL+C"
  pause_function
}

system_verifications() {
  check_root
  check_linux_distro
  detect_if_eufi
  check_network_connection
}

collect_parameters() {
  ## Deal with keymap first
  install_prereqs
  ask_for_keymap
  loadkeys "${KEYMAP}" # load the keymap

  ## Prompts
  print_info "Checking input parameters..."
  ask_for_os_to_install
  ask_for_edition_to_install
  ask_about_backports
  ask_should_support_hibernation
  ask_for_hostname
  ask_for_domain
  ask_for_timezone
  ask_for_main_disk
  ask_for_second_disk
  ask_should_encrypt_disks
  ask_for_disk_password
  ask_should_enable_root
  ask_for_root_password
  ask_should_create_user
  ask_for_user_name
  ask_for_user_password

  print_summary
  log_values
}

setup_disks() {
  unmount_partitions
  wipe_disks
  create_main_partitions
  create_secondary_partitions

  setup_encryption

  setup_lvm
  format_partitions
  mount_partitions
}

install_main_system() {
  install_base_system
  configure_locale
  install_bootloader
  install_virtualization
}

do_system_configurations() {
  configure_locale
  configure_keymap
  configure_fstab
  configure_hostname
  configure_timezone
  configure_initramfs
  configure_swap
  configure_networking
}

install_applications() {
  install_applications_debian
  install_applications_ubuntu
  install_applications_common
}

setup_users() {
  setup_root
  setup_user
}

wrap_up() {
  clean_up
  stamp_build
  show_complete_screen
}

### END: Script sections

### START: The Main Function

main() {
  export DEBIAN_FRONTEND=noninteractive

  # Preamble
  welcome_screen
  system_verifications

  # Prompts to the user (skipped if in auto install mode)
  collect_parameters

  # Setup the core system
  setup_disks
  install_main_system
  do_system_configurations

  # Configurations
  install_applications
  setup_users

  # Finished
  wrap_up

  if [[ ${USERNAME} == "vagrant" ]] || [[ "${AUTO_REBOOT_AT_END:-0}" == "1" ]]; then
    umount -R /mnt
    systemctl reboot
  fi
}

### END: The Main Function

main
