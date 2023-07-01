#!/usr/bin/env bash
# Author: Brennan Fee
# License: MIT License
# Version: 1.7
# Date: 2023-07-01
#
# Example to run directly from URL: bash <(curl -fsSL <url here>)
#
# Short URL: https://tinyurl.com/interactive-deb-install
# Github URL: https://raw.githubusercontent.com/brennanfee/linux-bootstraps/main/scripted-installer/debian/deb-install-interactive.bash
#
# Dev branch short URL: https://tinyurl.com/dev-interactive-deb-install
# Dev branch Github URL: https://raw.githubusercontent.com/brennanfee/linux-bootstraps/develop/scripted-installer/debian/deb-install-interactive.bash
#
# This script can be used to interactively install Debian/Ubuntu the "Arch" way.  It can
# also be used to produce a "configuration" file with the selected options during the
# interactive session.  The provided configuration file can then be used to automatically
# execute the installation with those settings.  This can provide a consistent install
# configuration for mutiple machines.
#
# At the end of the interactive questions you will be prompted whether you wish to export
# a configuration file or proceed and perform the installation.  While the export can be
# done on any machine and run in any Linux environment, for the installation to proceed
# you must have booted with a Debian (or Ubuntu) live "server" ISOs (which one shouldn't
# matter).
#
# Bash strict mode
([[ -n ${ZSH_EVAL_CONTEXT:-} && ${ZSH_EVAL_CONTEXT:-} =~ :file$ ]] ||
  [[ -n ${BASH_VERSION:-} ]] && (return 0 2>/dev/null)) && SOURCED=true || SOURCED=false
if ! ${SOURCED}; then
  set -o errexit  # same as set -e
  set -o nounset  # same as set -u
  set -o errtrace # same as set -E
  set -o pipefail
  set -o posix
  #set -o xtrace # same as set -x, turn on for debugging

  shopt -s inherit_errexit
  shopt -s extdebug
  IFS=$(printf '\n\t')
fi
# END Bash strict mode

### Start: Data

SCRIPT_AUTHOR="Brennan Fee"
SCRIPT_LICENSE="MIT License"
SCRIPT_VERSION="1.7"
SCRIPT_DATE="2023-07-01"

# The supported target OSes to be installed
SUPPORTED_OSES=('debian' 'ubuntu')
SUPPORTED_OSES_DISPLAY=('Debian' 'Ubuntu')

### End: Data

### Start: Constants & Global Variables

# Should only be on during testing.  Primarily this turns on the output of passwords.
IS_DEBUG=${AUTO_IS_DEBUG:=0}

# Paths
WORKING_DIR=$(pwd)
LOG="${WORKING_DIR}/interactive-install.log"
[[ -f ${LOG} ]] && rm -f "${LOG}"
INSTALL_DATE=$(date -Is)
echo "Start log: ${INSTALL_DATE}" >>"${LOG}"
echo "------------" >>"${LOG}"

# Console font size, I pre-configure the console font to enlarge it which should work better on higher resolution screens.
# The font family chosen is the Lat15-Terminus font family.  The only value changed here is the final size.
#
# Others small-ish: Lat15-Terminus14,Lat15-Terminus16,Lat15-Terminus18x10
# Others large-ish: Lat15-Terminus20x10,Lat15-Terminus22x11,Lat15-Terminus24x12,Lat15-Terminus28x14
CONSOLE_FONT_SIZE="20x10"

### End: Constants & Global Variables

### Start: Options (These Are The Defaults)

# This script will prompt for each of the values here, giving the user a chance to accept the default or override with a separate value.  For documentation on the allowed values please refer to the documentation for the deb-install script.

DEFAULT_KEYMAP="us"
DEFAULT_LOCALE="en_US.UTF-8"
DEFAULT_TIMEZONE="America/Chicago" # Suck it east and west coast!  ;-)

DEFAULT_INSTALL_OS="debian"
DEFAULT_INSTALL_EDITION="default"
DEFAULT_KERNEL_VERSION="default"
DEFAULT_REPO_OVERRIDE_URL=""

DEFAULT_HOSTNAME=""
DEFAULT_DOMAIN=""

DEFAULT_SKIP_PARTITIONING="0"
DEFAULT_MAIN_DISK="smallest"
DEFAULT_SECOND_DISK="ignore"
DEFAULT_ENCRYPT_DISKS="1"
DEFAULT_DISK_PWD="file"

DEFAULT_ROOT_DISABLED="0"
DEFAULT_ROOT_PWD=""
DEFAULT_CREATE_USER="1"
DEFAULT_USERNAME=""
DEFAULT_USER_PWD=""
DEFAULT_USER_SSH_KEY=""

DEFAULT_USE_DATA_DIR="0"
DEFAULT_STAMP_LOCATION=""
DEFAULT_CONFIG_MANAGEMENT="none"
DEFAULT_EXTRA_PACKAGES=""
DEFAULT_EXTRA_PREREQ_PACKAGES=""

DEFAULT_BEFORE_SCRIPT=""
DEFAULT_AFTER_SCRIPT=""
DEFAULT_FIRST_BOOT_SCRIPT=""

DEFAULT_CONFIRM_SETTINGS="1"
DEFAULT_REBOOT="0"

AUTO_KEYMAP="${DEFAULT_KEYMAP}"
AUTO_LOCALE="${DEFAULT_LOCALE}"
AUTO_TIMEZONE="${DEFAULT_TIMEZONE}"

AUTO_INSTALL_OS="${DEFAULT_INSTALL_OS}"
AUTO_INSTALL_EDITION="${DEFAULT_INSTALL_EDITION}"
AUTO_KERNEL_VERSION="${DEFAULT_KERNEL_VERSION}"
AUTO_REPO_OVERRIDE_URL="${DEFAULT_REPO_OVERRIDE_URL}"

AUTO_HOSTNAME="${DEFAULT_HOSTNAME}"
AUTO_DOMAIN="${DEFAULT_DOMAIN}"

AUTO_SKIP_PARTITIONING="${DEFAULT_SKIP_PARTITIONING}"
AUTO_MAIN_DISK="${DEFAULT_MAIN_DISK}"
AUTO_SECOND_DISK="${DEFAULT_SECOND_DISK}"
AUTO_ENCRYPT_DISKS="${DEFAULT_ENCRYPT_DISKS}"
AUTO_DISK_PWD="${DEFAULT_DISK_PWD}"

AUTO_ROOT_DISABLED="${DEFAULT_ROOT_DISABLED}"
AUTO_ROOT_PWD="${DEFAULT_ROOT_PWD}"
AUTO_CREATE_USER="${DEFAULT_CREATE_USER}"
AUTO_USERNAME="${DEFAULT_USERNAME}"
AUTO_USER_PWD="${DEFAULT_USER_PWD}"
AUTO_USER_SSH_KEY="${DEFAULT_USER_SSH_KEY}"

AUTO_USE_DATA_DIR="${DEFAULT_USE_DATA_DIR}"
AUTO_STAMP_LOCATION="${DEFAULT_STAMP_LOCATION}"
AUTO_CONFIG_MANAGEMENT="${DEFAULT_CONFIG_MANAGEMENT}"
AUTO_EXTRA_PACKAGES="${DEFAULT_EXTRA_PACKAGES}"
AUTO_EXTRA_PREREQ_PACKAGES="${DEFAULT_EXTRA_PREREQ_PACKAGES}"

AUTO_BEFORE_SCRIPT="${DEFAULT_BEFORE_SCRIPT}"
AUTO_AFTER_SCRIPT="${DEFAULT_AFTER_SCRIPT}"
AUTO_FIRST_BOOT_SCRIPT="${DEFAULT_FIRST_BOOT_SCRIPT}"

AUTO_CONFIRM_SETTINGS="${DEFAULT_CONFIRM_SETTINGS}"
AUTO_REBOOT="${DEFAULT_REBOOT}"

SELECTED_ACTION="export"
SELECTED_EXPORT_FILE="my-config.bash"

### END: Options

### START: Log Functions

write_log() {
  echo -e "LOG: ${1}" >>"${LOG}"
}

write_log_password() {
  if [[ ${IS_DEBUG} == "1" ]]; then
    echo -e "LOG: ${1}" >>"${LOG}"
  else
    local val
    val=${1//:*/: ******}
    echo -e "LOG: ${val}" >>"${LOG}"
  fi
}

write_log_blank() {
  write_log ""
}

write_log_spacer() {
  write_log "------"
}

### START: Log Functions

### START: Print Functions

# Text modifiers
RESET="$(tput sgr0)"
BOLD="$(tput bold)"

print_line() {
  local T_COLS
  T_COLS=$(tput cols)
  printf "%${T_COLS}s\n" | tr ' ' '-'
  write_log_spacer
}

blank_line() {
  echo "" |& tee -a "${LOG}"
}

print_title() {
  clear
  print_line
  local text="Deb-Install Automated Bootstrapper - Author: ${SCRIPT_AUTHOR} - License: ${SCRIPT_LICENSE}"
  echo -e "# ${BOLD}${text}${RESET}"
  write_log "TITLE: ${text}"
  print_line
  blank_line
}

print_section() {
  clear
  print_line
  echo -e "# ${BOLD}$1${RESET}"
  echo -e "SECTION: ${1}" >>"${LOG}"
  print_line
  blank_line
}

print_section_info() {
  T_COLS=$(tput cols)
  echo -e "${BOLD}$1${RESET}\n" | fold -sw $((T_COLS - 18)) | sed 's/^/\t/'
  print_line
  blank_line
  echo -e "SECTION-INFO: ${1}" >>"${LOG}"
}

print_summary_header() {
  local T_COLS
  T_COLS=$(tput cols)
  T_COLS=$((T_COLS - 10))
  echo -e "${BOLD}$1${RESET}\n\n${BOLD}$2${RESET}\n" | fold -sw "${T_COLS}" | sed 's/^/\t/'
  write_log "SUMMARY HEADER : ${1}"
  write_log "SUMMARY INFO : ${2}"
}

print_status() {
  T_COLS=$(tput cols)
  echo -e "$1${RESET}" | fold -sw $((T_COLS - 1))
  echo -e "STATUS: ${1}" >>"${LOG}"
}

print_info() {
  T_COLS=$(tput cols)
  echo -e "${BOLD}$1${RESET}" | fold -sw $((T_COLS - 1))
  echo -e "INFO: ${1}" >>"${LOG}"
}

print_warning() {
  local YELLOW
  YELLOW="$(tput setaf 3)"
  local T_COLS
  T_COLS=$(tput cols)
  T_COLS=$((T_COLS - 1))
  echo -e "${YELLOW}$1${RESET}" | fold -sw "${T_COLS}"
  write_log "WARN: ${1}"
}

print_success() {
  local GREEN
  GREEN="$(tput setaf 2)"
  local T_COLS
  T_COLS=$(tput cols)
  T_COLS=$((T_COLS - 1))
  echo -e "${GREEN}$1${RESET}" | fold -sw "${T_COLS}"
  write_log "SUCCESS: ${1}"
}

error_msg() {
  local RED
  RED="$(tput setaf 1)"
  local T_COLS
  T_COLS=$(tput cols)
  T_COLS=$((T_COLS - 1))
  echo -e "${RED}$1${RESET}\n" | fold -sw "${T_COLS}"
  write_log "ERROR: ${1}"
  exit 1
}

pause_output() {
  print_line
  read -re -sn 1 -p "Press enter to continue..."
}

invalid_option() {
  print_line
  if [[ ${1:=} == "" ]]; then
    print_warning "Invalid option. Try again."
  else
    print_warning "$1"
  fi
}

invalid_option_error() {
  print_line
  error_msg "Invalid option."
}

### END: Print Functions

### START: Helper Functions

get_exit_code() {
  EXIT_CODE=0
  # We first disable errexit in the current shell
  set +e
  (
    # Then we set it again inside a subshell
    set -e
    # ...and run the function
    "$@"
  )
  EXIT_CODE=$?
  # And finally turn errexit back on in the current shell
  set -e
}

contains_element() {
  #check if an element exist in a string
  for e in "${@:2}"; do
    [[ ${e} == "$1" ]] && break
  done
}

local_install() {
  write_log "Installing locally: '$*'"
  DEBIAN_FRONTEND=noninteractive apt-get -y -q --no-install-recommends install "$@"
}

### END: Helper Functions

### START: Verification Functions

check_root() {
  print_info "Checking root permissions..."

  local user_id
  user_id=$(id -u)
  if [[ "${user_id}" != "0" ]]; then
    error_msg "ERROR! You must execute the script as the 'root' user."
  fi
}

check_netcheck_network_connection() {
  print_info "Checking network connectivity..."

  # Check localhost first (if network stack is up at all)
  if ping -q -w 3 -c 2 localhost &>/dev/null; then
    # Test the gateway
    gateway_ip=$(ip r | grep default | awk 'NR==1 {print $3}')
    if ping -q -w 3 -c 2 "${gateway_ip}" &>/dev/null; then
      # Should we also ping the install mirror?
      print_info "Connection found."
    else
      error_msg "Gateway connection not accessible.  Exiting."
    fi
  else
    error_msg "Localhost network connection not found.  Exiting."
  fi
}

system_verifications() {
  check_root
  check_netcheck_network_connection
}

### END: Verification Functions

### START: Prereqs and Setup

install_prereqs() {
  print_info "Checking prerequisites"
  local missing_packages=0
  local prereq_packages=('vim' 'console-data' 'locales' 'fbset')
  local package

  for package in "${prereq_packages[@]}"; do
    if ! dpkg-query -f '${binary:Package}\n' -W | grep "^${package}$"; then
      missing_packages=1
      break
    fi
  done

  if [[ ${missing_packages} == "1" ]]; then
    print_info "Installing prerequisites"
    DEBIAN_FRONTEND=noninteractive apt-get -y -q update || true
    DEBIAN_FRONTEND=noninteractive apt-get -y -q full-upgrade || true
    DEBIAN_FRONTEND=noninteractive apt-get -y -q autoremove || true

    # Things all systems need (reminder these are being installed to the installation environment, not the target machine)
    print_status "    Installing common prerequisites"
    local_install vim console-data locales fbset
  fi
}

setup_installer_environment() {
  # Locale
  local current_locale
  current_locale=$(localectl status | grep -i 'system locale' | cut -d: -f 2 | cut -d= -f 2)
  if [[ ${current_locale} != "${AUTO_LOCALE}" ]]; then
    localectl set-locale "${AUTO_LOCALE}"
    export LC_ALL="${AUTO_LOCALE}"
  fi

  # Keymap
  loadkeys "${AUTO_KEYMAP}"

  # Resolution
  local detected_virt
  detected_virt=$(systemd-detect-virt || true)
  if [[ ${detected_virt} == "oracle" ]]; then
    fbset -xres 1280 -yres 720 -depth 32 -match
  fi

  # Font
  setfont "Lat15-Terminus${CONSOLE_FONT_SIZE}"
}

### START: Prompts & User Interaction

welcome_screen() {
  write_log "In welcome screen."
  print_title
  print_status "Interactive script to install Debian and Ubuntu systems the 'Arch Way' (aka deboostrap)."
  blank_line
  print_status "Script version: ${SCRIPT_VERSION} - Script date: ${SCRIPT_DATE}"
  blank_line
  print_status "For more information, documentation, or help:  https://github.com/brennanfee/linux-bootstraps"
  blank_line
  print_line
  blank_line
  print_status "Script can be canceled at any time with CTRL+C"
  blank_line
  pause_output
}

ask_for_keymap() {
  write_log "In ask for keymap."

  print_section "Keymap"
  print_section_info "Pick a keymap for the machine.  Press enter to accept the default."
  local input
  read -rp "Keymap [${AUTO_KEYMAP}]: " input
  if [[ ${input} != "" ]]; then
    AUTO_KEYMAP=${input}
  fi

  write_log "Kemap to use: ${AUTO_KEYMAP}"
}

ask_for_locale() {
  write_log "In ask for locale."

  print_section "Locale"
  print_section_info "Pick the locale to use for the machine.  Press enter to accept the default."
  local input
  read -rp "Locale [${AUTO_LOCALE}]: " input
  if [[ ${input} != "" ]]; then
    AUTO_LOCALE=${input}
  fi

  write_log "Locale to use: ${AUTO_LOCALE}"
}

ask_for_timezone() {
  write_log "In ask for timezone."

  print_section "Timezone"
  print_section_info "Enter a timezone for the machine.  Press enter to accept the default."
  local input
  read -rp "Domain [${AUTO_TIMEZONE}]: " input
  if [[ ${input} != "" ]]; then
    AUTO_TIMEZONE=${input}
  fi

  # TODO: Validate?

  write_log "Timezone to use: ${AUTO_TIMEZONE}"
}

ask_for_os_to_install() {
  write_log "In ask for os to install."

  print_section "OS To Install"
  print_section_info "Pick an OS to install."
  local input_os
  select input_os in "${SUPPORTED_OSES_DISPLAY[@]}"; do
    get_exit_code contains_element "${input_os}" "${SUPPORTED_OSES_DISPLAY[@]}"
    if [[ ${EXIT_CODE} == "0" ]]; then
      break
    else
      invalid_option
    fi
  done

  local install_os
  install_os=$(echo "${input_os}" | tr "[:upper:]" "[:lower:]")

  write_log "Selected OS before validation: ${install_os}"

  # Validate it
  get_exit_code contains_element "${install_os}" "${SUPPORTED_OSES[@]}"
  print_status "exit code: ${EXIT_CODE}"
  if [[ ${EXIT_CODE} != "0" ]]; then
    error_msg "Invalid OS to install selected."
  else
    AUTO_INSTALL_OS="${install_os}"
  fi

  write_log "OS to install: ${AUTO_INSTALL_OS}"
}

ask_for_edition_to_install() {
  write_log "In ask for os edition to install."

  print_section "OS Edition To Install"
  print_section_info "Enter an edition to install.  You can enter an edition like 'stable' or 'testing' for Debian, or 'lts' or 'rolling' for Ubuntu.  You can also enter a specific codename for the given distribution, such as 'bullseye' or 'jammy'.  Entering 'default' will auto-select the latest stable release available (the same as 'stable' for Debian or 'lts' for Ubuntu).  Press enter to accept the default."

  local input
  read -rp "OS Edition [${AUTO_INSTALL_EDITION}]: " input
  if [[ ${input} != "" ]]; then
    AUTO_INSTALL_EDITION=${input}
  fi
  # Normalize
  AUTO_INSTALL_EDITION=$(echo "${AUTO_INSTALL_EDITION}" | tr "[:upper:]" "[:lower:]")

  # Validate
  # TODO: TBD

  write_log "OS edition to install: ${AUTO_INSTALL_EDITION}"
}

ask_for_kernel_version() {
  write_log "In ask for kernel version."

  case "${AUTO_INSTALL_OS}" in
  debian)
    ask_for_debian_kernel_version
    ;;
  ubuntu)
    ask_for_ubuntu_kernel_version
    ;;
  *)
    error_msg "ERROR! OS to install not supported: '${AUTO_INSTALL_OS}'"
    ;;
  esac
}

ask_for_debian_kernel_version() {
  write_log "In ask for DEBIAN kernel version."

  # For Debian, we only need to ask about kernel version for certain release (which support backports).
  local dont_support_backports=("sid" "unstable" "rc-buggy" "experimental" "testing")
  get_exit_code contains_element "${AUTO_INSTALL_EDITION}" "${dont_support_backports[@]}"
  if [[ ! ${EXIT_CODE} == "0" ]]; then
    print_section "Kernel Version To Install"
    print_section_info "Pick a Kernel Version to install.  Note that if the backport kernel is requested but it is not available, the default kernel will be installed."

    local options=('default' 'backports')

    local input_version
    select input_version in "${options[@]}"; do
      get_exit_code contains_element "${input_version}" "${options[@]}"
      if [[ ${EXIT_CODE} == "0" ]]; then
        break
      else
        invalid_option
      fi
    done

    AUTO_KERNEL_VERSION=${input_version}
  fi

  write_log "Kernel edition to install: ${AUTO_KERNEL_VERSION}"
}

ask_for_ubuntu_kernel_version() {
  write_log "In ask for UBUNTU kernel version."

  print_section "Kernel Version To Install"
  print_section_info "Pick a Kernel Version to install.  Note that the installer will regressively fall back if the requested kernel edition is not available.  If hwe-edge is requested but only hwe is available, you will get hwe.  If neither are aviable, the default kernel will be installed."

  local options=('default' 'hwe' 'hwe-edge')

  local input_version
  select input_version in "${options[@]}"; do
    get_exit_code contains_element "${input_version}" "${options[@]}"
    if [[ ${EXIT_CODE} == "0" ]]; then
      break
    else
      invalid_option
    fi
  done

  AUTO_KERNEL_VERSION=${input_version}
  write_log "Kernel edition to install: ${AUTO_KERNEL_VERSION}"
}

ask_for_repo_override_url() {
  write_log "In ask for repo override url."

  print_section "Override Repo URL"
  print_section_info "If desired, input an override for the APT repository to use for installation, leave blank for no override.  Press enter to accept the default (no override)."

  local input
  read -rp "APT Repository Override URL [${AUTO_REPO_OVERRIDE_URL}]: " input
  if [[ ${input} != "" ]]; then
    AUTO_REPO_OVERRIDE_URL=${input}
  fi

  # No real validation here, just expect the user knows what they are doing.

  write_log "APT Repo Override URL: ${AUTO_REPO_OVERRIDE_URL}"
}

ask_for_hostname() {
  write_log "In ask for hostname."

  print_section "Hostname"
  print_section_info "Enter a hostname for this machine.  If left blank, a random hostname will be generated at installation time.  Press enter to accept the default."
  local input
  read -rp "Hostname [${AUTO_HOSTNAME}]: " input
  if [[ ${input} != "" ]]; then
    AUTO_HOSTNAME=${input}
  fi

  write_log "Hostname to use: ${AUTO_HOSTNAME}"
}

ask_for_domain() {
  write_log "In ask for domain."

  print_section "Domain"
  print_section_info "Enter a domain for this machine.  If left blank, no domain will be configured on the machine.  Press enter to accept the default."
  local input
  read -rp "Domain [${AUTO_DOMAIN}]: " input
  if [[ ${input} != "" ]]; then
    AUTO_DOMAIN=${input}
  fi

  write_log "Domain to use: ${AUTO_DOMAIN}"
}

ask_should_skip_partitioning() {
  write_log "In ask should skip partitioning."

  print_section "Disk Partitioning"
  print_section_info "Should the script skip automatic partitioning or not?  If you skip automatic partitioning it is expected that before deb-install runs, that all partitions are formatted and mounted at or under /mnt and are ready for installation.  This can be done manually before you execute the deb-install script or using a 'before script'.\n\nShould the automatic partitioning be skipped?"

  local yes_no=('No' 'Yes')
  local option
  select option in "${yes_no[@]}"; do
    get_exit_code contains_element "${option}" "${yes_no[@]}"
    if [[ ${EXIT_CODE} == "0" ]]; then
      break
    else
      invalid_option
    fi
  done

  option=$(echo "${option}" | tr "[:upper:]" "[:lower:]")
  case "${option}" in
  yes)
    AUTO_SKIP_PARTITIONING=1
    ;;
  no)
    AUTO_SKIP_PARTITIONING=0
    ;;
  *)
    error_msg "Invalid selection for skipping automatic disk partitioning."
    ;;
  esac

  write_log "Should skip disk partitioning: ${AUTO_SKIP_PARTITIONING}"
}

ask_for_main_disk() {
  write_log "In ask for main disk."

  if [[ ${AUTO_SKIP_PARTITIONING} == 1 ]]; then
    ask_for_main_disk_skipped_partition
  else
    print_section "Main Disk Selection"
    print_section_info "How do you want to determine the main\root disk to install? Select 'Smallest' (the default) to auto-select the smallest disk, 'Largest' to auto-select the largest disk, or 'Direct' to enter a device path manually (such as /dev/sda)."

    local disk_options=('Smallest' 'Largest' 'Direct')
    local option
    select option in "${disk_options[@]}"; do
      get_exit_code contains_element "${option}" "${disk_options[@]}"
      if [[ ${EXIT_CODE} == "0" ]]; then
        break
      else
        invalid_option
      fi
    done

    option=$(echo "${option}" | tr "[:upper:]" "[:lower:]")
    case "${option}" in
    smallest)
      AUTO_MAIN_DISK="smallest"
      ;;
    largest)
      AUTO_MAIN_DISK="largest"
      ;;
    direct)
      while :; do
        blank_line
        local input
        read -rp "Enter in the device: " input
        if [[ ${input} == /dev/* ]]; then
          AUTO_MAIN_DISK=${input}
          break
        else
          invalid_option "You must input a device such as /dev/sda, starting with /dev/"
        fi
      done
      ;;
    *)
      error_msg "Invalid main disk selection method provided."
      ;;
    esac

    write_log "Main disk selected: ${AUTO_MAIN_DISK}"
  fi
}

ask_for_main_disk_skipped_partition() {
  write_log "In ask for main disk (skipped partition version)."

  print_section "Main Disk Selection"
  print_section_info "Even when skipping automatic partitioning, you still need to indicate which disk should be used to install the GRUB bootloader to.  This must be manually entered as a device name (no auto selection option is supported)."

  while :; do
    blank_line
    local input
    read -rp "Enter in the device: " input
    if [[ ${input} == /dev/* ]]; then
      AUTO_MAIN_DISK=${input}
      break
    else
      invalid_option "You must input a device such as /dev/sda, starting with /dev/"
    fi
  done

  write_log "Main disk selected: ${AUTO_MAIN_DISK}"
}

ask_for_second_disk() {
  write_log "In ask for second disk."

  # Only need to ask about second disks if doing auto partitioning
  AUTO_SECOND_DISK="ignore" # the default
  if [[ ${AUTO_SKIP_PARTITIONING} == 0 ]]; then
    print_section "Second Disk Selection"
    print_section_info "What to do if the system has a second (or more) disks.  Select 'Ignore' (the default) to ignore the other disks and only use the main disk, 'Smallest' to auto-select the smallest disk (or next smallest, after the main disk), 'Largest' to auto-select the largest disk (or next largest, after the main disk), or 'Direct' to type in a device to use manually."

    local disk_options=('Ignore' 'Smallest' 'Largest' 'Direct')
    local option
    select option in "${disk_options[@]}"; do
      get_exit_code contains_element "${option}" "${disk_options[@]}"
      if [[ ${EXIT_CODE} == "0" ]]; then
        break
      else
        invalid_option
      fi
    done

    option=$(echo "${option}" | tr "[:upper:]" "[:lower:]")
    case "${option}" in
    ignore)
      AUTO_SECOND_DISK="ignore"
      ;;
    smallest)
      AUTO_SECOND_DISK="smallest"
      ;;
    largest)
      AUTO_SECOND_DISK="largest"
      ;;
    direct)
      while :; do
        blank_line
        local input
        read -rp "Enter in the device: " input
        if [[ ${input} == /dev/* ]]; then
          if [[ ${input} == "${AUTO_MAIN_DISK}" ]]; then
            invalid_option "The second disk cannot match the main disk.  Enter a different device."
          else
            AUTO_SECOND_DISK=${input}
            break
          fi
        else
          invalid_option "You must input a device such as /dev/sda, starting with /dev/"
        fi
      done
      ;;
    *)
      error_msg "Invalid second disk selection method provided."
      ;;
    esac
  fi

  write_log "Second disk selected: ${AUTO_SECOND_DISK}"
}

ask_should_encrypt_disks() {
  write_log "In ask should encrypt disks."

  # Only need to ask about encryption if doing auto partitioning
  AUTO_ENCRYPT_DISKS="0" # the default
  if [[ ${AUTO_SKIP_PARTITIONING} == 0 ]]; then
    print_section "Disk Encryption"
    print_section_info "Should the disks be encrypted?"
    local yes_no=('Yes' 'No')
    local option
    select option in "${yes_no[@]}"; do
      get_exit_code contains_element "${option}" "${yes_no[@]}"
      if [[ ${EXIT_CODE} == "0" ]]; then
        break
      else
        invalid_option
      fi
    done

    option=$(echo "${option}" | tr "[:upper:]" "[:lower:]")
    case "${option}" in
    yes)
      AUTO_ENCRYPT_DISKS=1
      ;;
    no)
      AUTO_ENCRYPT_DISKS=0
      ;;
    *)
      error_msg "Invalid selection for disk encryption."
      ;;
    esac
  fi

  write_log "Should disks be encrypted: ${AUTO_ENCRYPT_DISKS}"
}

ask_for_disk_password() {
  write_log "In ask for disk password."

  # Only need to ask if disk encryption was selected
  AUTO_DISK_PWD="file"
  if [[ ${AUTO_ENCRYPT_DISKS} == 1 ]]; then
    print_section "Disk Passphrase"
    print_section_info "How do you want the disk passphrase to be selected.  You can select 'File' (the default) and an randomly generated encryption file will be used, 'Path' and you can provide a path to a file to use, or 'URL' for a downloadable file to use.  These three options are best used for automated environments where a password entry for boot would be inconvenient yet encrypting the disks is still desired.  It also allows changing the encryption key setup later on after the machine is bootstrapped, which is highly secure given the default setup does not secure the key files.  Lastly, you can select 'Passphrase' to enter a passhprase to use.  Please note that using 'Passphrase' may break any automations in the system configuration as entering the password manually will be required at boot."

    local encryption_options=('File' 'Path' 'URL' 'Passphrase')
    local option
    select option in "${encryption_options[@]}"; do
      get_exit_code contains_element "${option}" "${encryption_options[@]}"
      if [[ ${EXIT_CODE} == "0" ]]; then
        break
      else
        invalid_option
      fi
    done

    option=$(echo "${option}" | tr "[:upper:]" "[:lower:]")
    case "${option}" in
    file)
      AUTO_DISK_PWD="file"
      ;;
    tpm) # Future
      AUTO_DISK_PWD="tpm"
      ;;
    path)
      while :; do
        blank_line
        local input
        read -rp "Enter in the file: " input
        if [[ ${input} == /* ]]; then
          AUTO_DISK_PWD=${input}
          break
        else
          invalid_option "You must input a full path to the file, releative paths are not supported."
        fi
      done
      ;;
    url)
      while :; do
        blank_line
        local input
        read -rp "Enter in the URL: " input
        if [[ ${input} == http://* || ${input} == https:// ]]; then
          AUTO_DISK_PWD=${input}
          break
        else
          invalid_option "You must input a valid URL.  At present only HTTP and HTTPS are supported URL schemas."
        fi
      done
      ;;
    passphrase)
      local was_set=0

      blank_line
      while [[ ${was_set} == 0 ]]; do
        local pwd1=""
        local pwd2=""
        read -srp "Disk passphrase: " pwd1
        echo -e ""
        read -srp "Once again: " pwd2

        if [[ "${pwd1}" == "${pwd2}" ]]; then
          AUTO_DISK_PWD="${pwd1}"
          was_set=1
        else
          blank_line
          print_warning "The passwords entered did not match... try again."
        fi
      done
      ;;
    *)
      error_msg "Invalid disk password option selected."
      ;;
    esac
  fi

  write_log_password "Disk password option: '${AUTO_DISK_PWD}'"
}

ask_should_enable_root() {
  write_log "In ask should enable root."

  print_section "Disable Root Account"
  print_section_info "Should the root account be disabled?"

  local yes_no=('No' 'Yes')
  local option
  select option in "${yes_no[@]}"; do
    get_exit_code contains_element "${option}" "${yes_no[@]}"
    if [[ ${EXIT_CODE} == "0" ]]; then
      break
    else
      invalid_option
    fi
  done

  option=$(echo "${option}" | tr "[:upper:]" "[:lower:]")
  case "${option}" in
  yes)
    AUTO_ROOT_DISABLED=1
    ;;
  no)
    AUTO_ROOT_DISABLED=0
    ;;
  *)
    error_msg "Invalid selection for disable root account."
    ;;
  esac

  write_log "Should root be disabled: ${AUTO_ROOT_DISABLED}"
}

ask_for_root_password() {
  write_log "In ask for root password."

  AUTO_ROOT_PWD="" # the default

  if [[ ${AUTO_ROOT_DISABLED} == 1 ]]; then
    # No need to prompt for password
    print_info "Skipping root password."
    return
  fi

  print_section "Root Password"
  print_section_info "Enter a password for root.  You can enter nothing to accept the default '${AUTO_INSTALL_OS}'."

  local was_set=0

  blank_line
  while [[ ${was_set} == 0 ]]; do
    local pwd1=""
    local pwd2=""
    read -srp "Password: " pwd1
    echo -e ""
    read -srp "Once again: " pwd2

    if [[ "${pwd1}" == "${pwd2}" ]]; then
      AUTO_ROOT_PWD="${pwd1}"
      was_set=1
    else
      blank_line
      print_warning "They did not match... try again."
    fi
  done

  write_log_password "Root password: ${AUTO_ROOT_PWD}"
}

ask_should_create_user() {
  write_log "In ask should create user."

  if [[ ${AUTO_ROOT_DISABLED} == 1 ]]; then
    print_info "Root user disabled, skipping prompt because a user MUST be created."
    AUTO_CREATE_USER=1
    return
  fi

  print_section "Create User Account"
  print_section_info "Should a user account be created?"

  local yes_no=('No' 'Yes')
  local option
  select option in "${yes_no[@]}"; do
    get_exit_code contains_element "${option}" "${yes_no[@]}"
    if [[ ${EXIT_CODE} == "0" ]]; then
      break
    else
      invalid_option
    fi
  done

  option=$(echo "${option}" | tr "[:upper:]" "[:lower:]")
  case "${option}" in
  yes)
    AUTO_CREATE_USER=1
    ;;
  no)
    AUTO_CREATE_USER=0
    ;;
  *)
    error_msg "Invalid selection for creating user account."
    ;;
  esac

  write_log "Should a user be created: ${AUTO_CREATE_USER}"
}

ask_for_user_name() {
  write_log "In ask for username."

  AUTO_USERNAME="" # the default

  if [[ ${AUTO_CREATE_USER} == 0 ]]; then
    print_info "Skipping username prompt as user creation was disabled."
    return
  fi

  print_section "User"
  print_section_info "Enter a username to create.  You can enter nothing to accept the default '${AUTO_INSTALL_OS}'."
  local input=""
  read -rp "Username [${AUTO_INSTALL_OS}]: " input
  if [[ ${input} != "" ]]; then
    AUTO_USERNAME=${input}
  fi

  local username=${AUTO_USERNAME}
  if [[ ${username} == "" ]]; then
    username=${AUTO_INSTALL_OS}
  fi

  write_log "Username To Create: '${username}'"
}

ask_for_user_password() {
  write_log "In ask for user password."

  AUTO_USER_PWD="" # the default

  if [[ ${AUTO_CREATE_USER} == 0 ]]; then
    print_info "Skipping user password prompt as user creation was disabled."
    return
  fi

  local username=${AUTO_USERNAME}
  if [[ ${username} == "" ]]; then
    username=${AUTO_INSTALL_OS}
  fi

  print_section "User Password"
  print_section_info "Enter a password for the user '${username}'.  You can enter nothing to accept the default '${AUTO_INSTALL_OS}'."

  local was_set=0

  blank_line
  while [[ ${was_set} == 0 ]]; do
    local pwd1=""
    local pwd2=""
    read -srp "Password: " pwd1
    echo -e ""
    read -srp "Once again: " pwd2

    if [[ "${pwd1}" == "${pwd2}" ]]; then
      AUTO_USER_PWD="${pwd1}"
      was_set=1
    else
      blank_line
      print_warning "They did not match... try again."
    fi
  done

  write_log_password "User password: ${AUTO_USER_PWD}"
}

ask_for_user_ssh_key() {
  write_log "In ask for user ssh key."

  AUTO_USER_SSH_KEY="" # the default

  if [[ ${AUTO_CREATE_USER} == 0 ]]; then
    print_info "Skipping user ssh key prompt as user creation was disabled."
    return
  fi

  local username=${AUTO_USERNAME}
  if [[ ${username} == "" ]]; then
    username=${AUTO_INSTALL_OS}
  fi

  print_section "User SSH Key (Optional)"
  print_section_info "Enter a private SSH Key to use for the user '${username}'.  You can enter nothing to accept the default of not providing an SSH key to use (password SSH will still be supported initially)."

  local input=""
  read -rp "User SSH Key: " input
  if [[ ${input} != "" ]]; then
    AUTO_USER_SSH_KEY=${input}
  fi

  write_log_password "User SSH Key: ${AUTO_USER_SSH_KEY}"
}

ask_should_use_data_directory() {
  write_log "In ask should use data directory."

  print_section "Use Data Directory"
  print_section_info "The script provides an option to use a 'data' directory.  This selection may influence the partition scheme, mostly with multi-disk scenarios.  The script will create a group with permissions to the 'data' directory and grant the installed user (if any) permissions through that group."

  local yes_no=('No' 'Yes')
  local option
  select option in "${yes_no[@]}"; do
    get_exit_code contains_element "${option}" "${yes_no[@]}"
    if [[ ${EXIT_CODE} == "0" ]]; then
      break
    else
      invalid_option
    fi
  done

  option=$(echo "${option}" | tr "[:upper:]" "[:lower:]")
  case "${option}" in
  yes)
    AUTO_USE_DATA_DIR=1
    ;;
  no)
    AUTO_USE_DATA_DIR=0
    ;;
  *)
    error_msg "Invalid selection for using data directory."
    ;;
  esac

  write_log "Use data directory: ${AUTO_USE_DATA_DIR}"
}

ask_override_stamp_location() {
  write_log "In ask override stamp location."

  print_section "Stamp Location"
  print_section_info "The script automatically 'stamps' some files into an auto-selected directory on the machine.  The file contains the date and time of the installation, the log files for the installation, and some other miscellaneous bits.  By default the /srv directory (or /data directory, if that option was selected) will be used.  You can enter a different location here.  If left blank, the default will be used."
  local input
  read -rp "Override Stamp Location: " input
  if [[ ${input} != "" ]]; then
    AUTO_STAMP_LOCATION=${input}
  fi

  write_log "Stamp location override: ${AUTO_STAMP_LOCATION}"
}

ask_install_configuration_management() {
  #AUTO_CONFIG_MANAGEMENT
  write_log "In ask to install change management."

  print_section "Change Management"
  print_section_info "The script supports installing some configuration management software.  This can be useful for situations where an agent needs to be installed after first boot in order for the machine to be configured automatically.  Some of the options are from the standard Apt repository, while others are alternative installation mechanisms which may be necessary to obtain the newest versions of the configuration management software.  Selecting 'none', the default, means no configuration management software will be installed."

  local config_options=('None' 'Ansible (From Apt)' 'Ansible (Using Pip)' 'Salt (From Apt)' 'Salt (From Repo)' 'Puppet (From Apt)' 'Puppet (From Repo)')
  local option
  select option in "${config_options[@]}"; do
    get_exit_code contains_element "${option}" "${config_options[@]}"
    if [[ ${EXIT_CODE} == "0" ]]; then
      break
    else
      invalid_option
    fi
  done

  case "${option}" in
  "None")
    AUTO_CONFIG_MANAGEMENT="none"
    ;;
  "Ansible (From Apt)")
    AUTO_CONFIG_MANAGEMENT="ansible"
    ;;
  "Ansible (Using Pip)")
    AUTO_CONFIG_MANAGEMENT="ansible-pip"
    ;;
  "Salt (From Apt)")
    AUTO_CONFIG_MANAGEMENT="salt"
    ;;
  "Salt (From Repo)")
    AUTO_CONFIG_MANAGEMENT="salt-repo"
    ;;
  "Puppet (From Apt)")
    AUTO_CONFIG_MANAGEMENT="puppet"
    ;;
  "Puppet (From Repo)")
    AUTO_CONFIG_MANAGEMENT="puppet-repo"
    ;;
  *)
    error_msg "Invalid option for configuration management."
    ;;
  esac

  write_log "Configuration Management To Install: ${AUTO_CONFIG_MANAGEMENT}"
}

ask_install_extra_packages() {
  write_log "In ask to install extra packages."

  print_section "Install Extra Packages"
  print_section_info "You can, optionally, provide a space separated list of Apt packages to be pre-installed."
  local input
  read -rp "Extra Packages To Install: " input
  if [[ ${input} != "" ]]; then
    AUTO_EXTRA_PACKAGES=${input}
  fi

  write_log "Extra packages to install: '${AUTO_EXTRA_PACKAGES}'"
}

ask_install_extra_prereq_packages() {
  AUTO_EXTRA_PREREQ_PACKAGES
  write_log "In ask to install extra prerequisite pre-installation packages."

  print_section "Install Extra Prerequisite Pre-installation Packages"
  print_section_info "You can, optionally, provide a space separated list of Apt packages to be installed into the pre-installation environment.  This may be desired if you are running a BEFORE or AFTER script and require some tooling or a specific scripting language to be installed."
  local input
  read -rp "Extra Prerequisite Pre-installation Packages To Install: " input
  if [[ ${input} != "" ]]; then
    AUTO_EXTRA_PREREQ_PACKAGES=${input}
  fi

  write_log "Extra prerequisite pre-installation packages to install: '${AUTO_EXTRA_PREREQ_PACKAGES}'"
}

ask_for_before_script() {
  write_log "In ask for before script."

  print_section "Execute A 'Before' Script"
  print_section_info "You can, optionally, provide a script that will run before the installation script runs.  This 'before' script can perform advanced actions such as disk partitioning.  Note that the target environment is not yet mounted at /mnt and therefore you cannot perform any chroot functionality.  The script can also export script options (export AUTO_TIMEZONE='value') which will be respected by the main script.  So, if you want settings to be based on some kind of logic or based on machine inspection, you may use the 'before' script to perform that logic.  The script does not have to be a bash script, but MUST have a shebang that properly indicates how the script should be run.  Please note that you will need to investigate that your preferred script language is supported in the pre-installation environment.  The value provided should be a URL that will be accessible by the installation machine.  The script will be downloaded from that location using wget, so any URL supported by wget will work.  Leaving this blank will skip execution of any 'before' script."

  local input
  read -rp "'Before' script to execute: " input
  if [[ ${input} != "" ]]; then
    AUTO_BEFORE_SCRIPT=${input}
  fi

  write_log "'Before' script to execute: '${AUTO_BEFORE_SCRIPT}'"
}

ask_for_after_script() {
  write_log "In ask for after script."

  print_section "Execute A 'After' Script"
  print_section_info "You can, optionally, provide a script that will run after the main installation but before the machine is rebooted (if reboot was requested).  This script can preform any extra configurations for the target installation.  The /mnt directory will still be available and chroot into that location is supported (you can even use the provided arch-chroot command to make tasks simpler).  The 'after' script SHOULD NOT unmount the /mnt directory.  The script does not have to be a bash script, but MUST have a shebang that properly indicates how the script should be run.  Please note that you will need to investigate that your preferred script language is supported in the pre-installation environment.  The value provided should be a URL that will be accessible by the installation machine.  The script will be downloaded from that location using wget, so any URL supported by wget will work.  Leaving this blank will skip execution of any 'after' script."

  local input
  read -rp "'After' script to execute: " input
  if [[ ${input} != "" ]]; then
    AUTO_AFTER_SCRIPT=${input}
  fi

  write_log "'After' script to execute: '${AUTO_AFTER_SCRIPT}'"
}

ask_for_first_boot_script() {
  write_log "In ask for after first boot script."

  print_section "Execute A 'First Boot' Script"
  print_section_info "You can, optionally, provide a script that will run on the first boot of the machine.  This script will run only once.  It can be used to perform after installation steps or kick off some external configuration process or basically do any kind of post-installation steps you might want.  The script will be named '/usr/local/sbin/first-boot.script' and it will not be removed after execution.  The script does not have to be a bash script, but MUST have a shebang that properly indicates how the script should be run.  Please note that you will need to ensure that the script language used is installed and supported in your taget environment (for instance by using AUTO_EXTRA_PACKAGES).  The value provided should be a URL that will be accessible by the installation machine.  The script will be downloaded from that location using wget, so any URL supported by wget will work.  Leaving this blank will skip execution of any 'first boot' script."

  local input
  read -rp "'First Boot' script to execute: " input
  if [[ ${input} != "" ]]; then
    AUTO_FIRST_BOOT_SCRIPT=${input}
  fi

  write_log "'First Boot' script to execute: '${AUTO_FIRST_BOOT_SCRIPT}'"
}

ask_about_settings_confirmation() {
  write_log "In ask about settings confirmation."

  print_section "Pause Script And Confirm Settings With User"
  print_section_info "Should the script pause and confirm the settings with the user before proceeding with installation?  Note that if you are trying to create a fully unattended and automatic installation this should be left off.  The default is to NOT confirm settings and proceed directly to installation."

  local yes_no=('No' 'Yes')
  local option
  select option in "${yes_no[@]}"; do
    get_exit_code contains_element "${option}" "${yes_no[@]}"
    if [[ ${EXIT_CODE} == "0" ]]; then
      break
    else
      invalid_option
    fi
  done

  option=$(echo "${option}" | tr "[:upper:]" "[:lower:]")
  case "${option}" in
  yes)
    AUTO_CONFIRM_SETTINGS=1
    ;;
  no)
    AUTO_CONFIRM_SETTINGS=0
    ;;
  *)
    error_msg "Invalid selection for settings confirmation."
    ;;
  esac

  write_log "Pause for settings confirmation: ${AUTO_CONFIRM_SETTINGS}"
}

ask_about_auto_reboot() {
  write_log "In ask about auto reboot."

  print_section "Auto Reboot After Installation"
  print_section_info "Should the script automatically reboot the machine after installation? Note that if you are trying to create a fully unattended and automatic installation this should be turned on.  The default is to NOT automatically reboot.  This gives the user the ability to run any manual steps and then reboot when they are ready."

  local yes_no=('No' 'Yes')
  local option
  select option in "${yes_no[@]}"; do
    get_exit_code contains_element "${option}" "${yes_no[@]}"
    if [[ ${EXIT_CODE} == "0" ]]; then
      break
    else
      invalid_option
    fi
  done

  option=$(echo "${option}" | tr "[:upper:]" "[:lower:]")
  case "${option}" in
  yes)
    AUTO_REBOOT=1
    ;;
  no)
    AUTO_REBOOT=0
    ;;
  *)
    error_msg "Invalid selection for auto reboot."
    ;;
  esac

  write_log "Should auto reboot: ${AUTO_REBOOT}"
}

print_summary() {
  print_title
  print_summary_header "Install Summary (Part 1)" "Below is a summary of your selections.  Review them carefully."
  print_line

  print_status "The selected keymap is '${AUTO_KEYMAP}', locale is '${AUTO_LOCALE}', and the selected timezone is '${AUTO_TIMEZONE}'."

  print_status "The distribution to install is '${AUTO_INSTALL_OS}', '${AUTO_INSTALL_EDITION}' edition."

  print_status "The kernel version to install, if available, is '${AUTO_KERNEL_VERSION}'."

  if [[ ${AUTO_REPO_OVERRIDE_URL} == "" ]]; then
    print_status "The installation repository URL will not be overridden."
  else
    print_status "The installation repository will be overridden, the URL to use is '${AUTO_REPO_OVERRIDE_URL}'."
  fi
  blank_line

  local domain_info
  if [[ ${AUTO_DOMAIN} != "" ]]; then
    domain_info="The domain selected is '${AUTO_DOMAIN}'."
  else
    domain_info="No domain was provided."
  fi
  if [[ ${AUTO_HOSTNAME} == "" ]]; then
    print_status "The hostname will be auto-generated. ${domain_info}"
  else
    print_status "The hostname selected is '${AUTO_HOSTNAME}'. ${domain_info}"
  fi
  blank_line

  if [[ ${AUTO_SKIP_PARTITIONING} == "1" ]]; then
    print_status "Automatic disk partitioning has been DISABLED.  You will need to manually setup the target /mnt directory, performing any needed disk partitioning and mounting.  This can be done either manually before calling this deb-install script or in a provided 'before' script."

    blank_line
    print_status "The main disk selected (for GRUB) was '${AUTO_MAIN_DISK}'."
  else
    print_status "The main disk selection option was '${AUTO_MAIN_DISK}'."
    print_status "The secondary disk selection option was '${AUTO_SECOND_DISK}'."

    local encryption_method
    case "${AUTO_DISK_PWD}" in
    file)
      encryption_method="generated file"
      ;;
    tpm) # Future
      encryption_method="tpm"
      ;;
    /*)
      encryption_method="provided file"
      ;;
    http://*)
      encryption_method="provided url"
      ;;
    https://*)
      encryption_method="provided url"
      ;;
    *)
      encryption_method="password"
      ;;
    esac

    if [[ ${AUTO_ENCRYPT_DISKS} == "1" ]]; then
      print_status "The disks will be encrypted.  Encryption method is: '${encryption_method}'."
    else
      print_status "The disks will NOT be encrypted."
    fi
  fi
  blank_line

  if [[ ${AUTO_ROOT_DISABLED} == "1" ]]; then
    print_status "The root account will be disabled."
  else
    print_status "The root account will be activated."
  fi

  if [[ ${AUTO_CREATE_USER} == "1" ]]; then
    if [[ ${AUTO_USERNAME} == "" ]]; then
      print_status "A default user '${AUTO_INSTALL_OS}' will be created and granted sudo permissions."
    else
      print_status "User '${AUTO_USERNAME}' will be created and granted sudo permissions."
    fi
    if [[ ${AUTO_USER_SSH_KEY} != "" ]]; then
      print_status "A public SSH key will be set up in the user account."
    else
      print_status "No public SSH key will be set up in the user account."
    fi
  else
    print_status "User creation was disabled."
  fi
  blank_line

  pause_output

  #### Second page
  print_title
  print_summary_header "Install Summary (Part 2)" "Below are more of your selections.  Review them carefully.  If anything is wrong cancel out now with Ctrl-C.  Otherwise press any key to continue."
  print_line

  if [[ ${AUTO_USE_DATA_DIR} == "1" ]]; then
    print_status "The data directory and related configurations will be deployed."
  else
    print_status "The data directory and related configurations are being SKIPPED."
  fi

  if [[ ${AUTO_STAMP_LOCATION} == "" ]]; then
    print_status "The default stamp location will be used."
  else
    print_status "The stamp location will be '${AUTO_STAMP_LOCATION}'."
  fi
  blank_line

  if [[ ${AUTO_CONFIG_MANAGEMENT} == "none" ]]; then
    print_status "No configuration management software will be pre-installed."
  else
    print_status "Configuration management software will be pre-installed: '${AUTO_CONFIG_MANAGEMENT}'."
  fi

  if [[ ${AUTO_EXTRA_PACKAGES} == "" ]]; then
    print_status "No extra packages have been requested to be pre-installed."
  else
    print_status "Extra packages have been selected to be pre-installed: '${AUTO_EXTRA_PACKAGES}'."
  fi
  if [[ ${AUTO_EXTRA_PREREQ_PACKAGES} == "" ]]; then
    print_status "No extra prerequisite pre-installation packages have been requested to be installed."
  else
    print_status "Extra prerequisite pre-installation packages have been selected to be installed: '${AUTO_EXTRA_PREREQ_PACKAGES}'."
  fi
  blank_line

  if [[ ${AUTO_BEFORE_SCRIPT} == "" ]]; then
    print_status "No 'before' script has been provided."
  else
    print_status "'Before' script selected is '${AUTO_BEFORE_SCRIPT}'."
  fi

  if [[ ${AUTO_AFTER_SCRIPT} == "" ]]; then
    print_status "No 'after' script has been provided."
  else
    print_status "'After' script selected is '${AUTO_AFTER_SCRIPT}'."
  fi

  if [[ ${AUTO_FIRST_BOOT_SCRIPT} == "" ]]; then
    print_status "No 'first boot' script has been provided."
  else
    print_status "'First boot' script selected is '${AUTO_FIRST_BOOT_SCRIPT}'."
  fi
  blank_line

  if [[ ${AUTO_CONFIRM_SETTINGS} == "1" ]]; then
    print_status "The installation will pause and confirm settings with the user."
  else
    print_status "The system will NOT confirm settings with the user and will automatically proceed to installation."
  fi

  if [[ ${AUTO_REBOOT} == "1" ]]; then
    print_status "The system will automatically reboot after installation."
  else
    print_status "The system will NOT automatically reboot after installation."
  fi
  blank_line

  pause_output
}

ask_export_or_execute() {
  write_log "In ask export or execute."

  print_section "Export Config File Or Execute Now"
  print_section_info "This interactive script can either export a script file that can be used to run the installation with the options selected.  The script created is useful for repeated installations with a similar configuration.  Alternatively, you can execute the installation now with the options selected.  Lastly, you can simply exit the script, losing all selected values."

  local options=('Export' 'Execute' 'Exit')
  local option
  select option in "${options[@]}"; do
    get_exit_code contains_element "${option}" "${options[@]}"
    if [[ ${EXIT_CODE} == "0" ]]; then
      break
    else
      invalid_option
    fi
  done

  option=$(echo "${option}" | tr "[:upper:]" "[:lower:]")
  SELECTED_ACTION="${option}"

  write_log "Selected script action: ${SELECTED_ACTION}"
}

ask_for_export_file() {
  write_log "In ask for export file."

  print_section "Export A Configuration Script"
  print_section_info "Enter a file name to export the configuration script?  Press enter to accept the default of 'my-config.bash'."

  local input
  read -rp "Export File Name [${SELECTED_EXPORT_FILE}]: " input
  if [[ ${input} != "" ]]; then
    SELECTED_EXPORT_FILE=${input}
  fi

  write_log "Export file selected: '${SELECTED_EXPORT_FILE}'"
}

output_exports() {
  write_log "In output_exports."

  if [[ ${DEFAULT_KEYMAP} != "${AUTO_KEYMAP}" ]]; then
    echo "  export AUTO_KEYMAP=${AUTO_KEYMAP}" >>"${SELECTED_EXPORT_FILE}"
  fi
  if [[ ${DEFAULT_LOCALE} != "${AUTO_LOCALE}" ]]; then
    echo "  export AUTO_LOCALE=${AUTO_LOCALE}" >>"${SELECTED_EXPORT_FILE}"
  fi
  if [[ ${DEFAULT_TIMEZONE} != "${AUTO_TIMEZONE}" ]]; then
    echo "  export AUTO_TIMEZONE=${AUTO_TIMEZONE}" >>"${SELECTED_EXPORT_FILE}"
  fi

  if [[ ${DEFAULT_INSTALL_OS} != "${AUTO_INSTALL_OS}" ]]; then
    echo "  export AUTO_INSTALL_OS=${AUTO_INSTALL_OS}" >>"${SELECTED_EXPORT_FILE}"
  fi
  if [[ ${DEFAULT_INSTALL_EDITION} != "${AUTO_INSTALL_EDITION}" ]]; then
    echo "  export AUTO_INSTALL_EDITION=${AUTO_INSTALL_EDITION}" >>"${SELECTED_EXPORT_FILE}"
  fi
  if [[ ${DEFAULT_KERNEL_VERSION} != "${AUTO_KERNEL_VERSION}" ]]; then
    echo "  export AUTO_KERNEL_VERSION=${AUTO_KERNEL_VERSION}" >>"${SELECTED_EXPORT_FILE}"
  fi
  if [[ ${DEFAULT_REPO_OVERRIDE_URL} != "${AUTO_REPO_OVERRIDE_URL}" ]]; then
    echo "  export AUTO_REPO_OVERRIDE_URL=${AUTO_REPO_OVERRIDE_URL}" >>"${SELECTED_EXPORT_FILE}"
  fi

  if [[ ${DEFAULT_HOSTNAME} != "${AUTO_HOSTNAME}" ]]; then
    echo "  export AUTO_HOSTNAME=${AUTO_HOSTNAME}" >>"${SELECTED_EXPORT_FILE}"
  fi
  if [[ ${DEFAULT_DOMAIN} != "${AUTO_DOMAIN}" ]]; then
    echo "  export AUTO_DOMAIN=${AUTO_DOMAIN}" >>"${SELECTED_EXPORT_FILE}"
  fi

  if [[ ${DEFAULT_SKIP_PARTITIONING} != "${AUTO_SKIP_PARTITIONING}" ]]; then
    echo "  export AUTO_SKIP_PARTITIONING=${AUTO_SKIP_PARTITIONING}" >>"${SELECTED_EXPORT_FILE}"
  fi
  if [[ ${DEFAULT_MAIN_DISK} != "${AUTO_MAIN_DISK}" ]]; then
    echo "  export AUTO_MAIN_DISK=${AUTO_MAIN_DISK}" >>"${SELECTED_EXPORT_FILE}"
  fi
  if [[ ${DEFAULT_SECOND_DISK} != "${AUTO_SECOND_DISK}" ]]; then
    echo "  export AUTO_SECOND_DISK=${AUTO_SECOND_DISK}" >>"${SELECTED_EXPORT_FILE}"
  fi
  if [[ ${DEFAULT_ENCRYPT_DISKS} != "${AUTO_ENCRYPT_DISKS}" ]]; then
    echo "  export AUTO_ENCRYPT_DISKS=${AUTO_ENCRYPT_DISKS}" >>"${SELECTED_EXPORT_FILE}"
  fi
  if [[ ${DEFAULT_DISK_PWD} != "${AUTO_DISK_PWD}" ]]; then
    echo "  export AUTO_DISK_PWD=${AUTO_DISK_PWD}" >>"${SELECTED_EXPORT_FILE}"
  fi

  if [[ ${DEFAULT_ROOT_DISABLED} != "${AUTO_ROOT_DISABLED}" ]]; then
    echo "  export AUTO_ROOT_DISABLED=${AUTO_ROOT_DISABLED}" >>"${SELECTED_EXPORT_FILE}"
  fi
  if [[ ${DEFAULT_ROOT_PWD} != "${AUTO_ROOT_PWD}" ]]; then
    echo "  export AUTO_ROOT_PWD=${AUTO_ROOT_PWD}" >>"${SELECTED_EXPORT_FILE}"
  fi
  if [[ ${DEFAULT_CREATE_USER} != "${AUTO_CREATE_USER}" ]]; then
    echo "  export AUTO_CREATE_USER=${AUTO_CREATE_USER}" >>"${SELECTED_EXPORT_FILE}"
  fi
  if [[ ${DEFAULT_USERNAME} != "${AUTO_USERNAME}" ]]; then
    echo "  export AUTO_USERNAME=${AUTO_USERNAME}" >>"${SELECTED_EXPORT_FILE}"
  fi
  if [[ ${DEFAULT_USER_PWD} != "${AUTO_USER_PWD}" ]]; then
    echo "  export AUTO_USER_PWD=${AUTO_USER_PWD}" >>"${SELECTED_EXPORT_FILE}"
  fi
  if [[ ${DEFAULT_USER_SSH_KEY} != "${AUTO_USER_SSH_KEY}" ]]; then
    echo "  export AUTO_USER_SSH_KEY=${AUTO_USER_SSH_KEY}" >>"${SELECTED_EXPORT_FILE}"
  fi

  if [[ ${DEFAULT_USE_DATA_DIR} != "${AUTO_USE_DATA_DIR}" ]]; then
    echo "  export AUTO_USE_DATA_DIR=${AUTO_USE_DATA_DIR}" >>"${SELECTED_EXPORT_FILE}"
  fi
  if [[ ${DEFAULT_STAMP_LOCATION} != "${AUTO_STAMP_LOCATION}" ]]; then
    echo "  export AUTO_STAMP_LOCATION=${AUTO_STAMP_LOCATION}" >>"${SELECTED_EXPORT_FILE}"
  fi
  if [[ ${DEFAULT_CONFIG_MANAGEMENT} != "${AUTO_CONFIG_MANAGEMENT}" ]]; then
    echo "  export AUTO_CONFIG_MANAGEMENT=${AUTO_CONFIG_MANAGEMENT}" >>"${SELECTED_EXPORT_FILE}"
  fi
  if [[ ${DEFAULT_EXTRA_PACKAGES} != "${AUTO_EXTRA_PACKAGES}" ]]; then
    echo "  export AUTO_EXTRA_PACKAGES=${AUTO_EXTRA_PACKAGES}" >>"${SELECTED_EXPORT_FILE}"
  fi
  if [[ ${DEFAULT_EXTRA_PREREQ_PACKAGES} != "${AUTO_EXTRA_PREREQ_PACKAGES}" ]]; then
    echo "  export AUTO_EXTRA_PREREQ_PACKAGES=${AUTO_EXTRA_PREREQ_PACKAGES}" >>"${SELECTED_EXPORT_FILE}"
  fi

  if [[ ${DEFAULT_BEFORE_SCRIPT} != "${AUTO_BEFORE_SCRIPT}" ]]; then
    echo "  export AUTO_BEFORE_SCRIPT=${AUTO_BEFORE_SCRIPT}" >>"${SELECTED_EXPORT_FILE}"
  fi
  if [[ ${DEFAULT_AFTER_SCRIPT} != "${AUTO_AFTER_SCRIPT}" ]]; then
    echo "  export AUTO_AFTER_SCRIPT=${AUTO_AFTER_SCRIPT}" >>"${SELECTED_EXPORT_FILE}"
  fi
  if [[ ${DEFAULT_FIRST_BOOT_SCRIPT} != "${AUTO_FIRST_BOOT_SCRIPT}" ]]; then
    echo "  export AUTO_FIRST_BOOT_SCRIPT=${AUTO_FIRST_BOOT_SCRIPT}" >>"${SELECTED_EXPORT_FILE}"
  fi

  if [[ ${DEFAULT_CONFIRM_SETTINGS} != "${AUTO_CONFIRM_SETTINGS}" ]]; then
    echo "  export AUTO_CONFIRM_SETTINGS=${AUTO_CONFIRM_SETTINGS}" >>"${SELECTED_EXPORT_FILE}"
  fi
  if [[ ${DEFAULT_REBOOT} != "${AUTO_REBOOT}" ]]; then
    echo "  export AUTO_REBOOT=${AUTO_REBOOT}" >>"${SELECTED_EXPORT_FILE}"
  fi
}

export_config() {
  write_log "In export_config."

  ask_for_export_file

  # First part of file...
  cat <<-'EOF' >"${SELECTED_EXPORT_FILE}"
#!/usr/bin/env bash
# Author: Generated by deb-install-interactive.bash script
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
EOF

  output_exports

  ## Remaining part of file
  cat <<-'EOF' >>"${SELECTED_EXPORT_FILE}"
}
##################  DO NOT MODIFY BELOW THIS SECTION

check_root() {
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
      wget -O "${script_file}" "${CONFIG_SCRIPT_SOURCE}"
    else
      wget -O "${script_file}" "${script_url}"
    fi
  fi
}

read_input_options() {
  # Defaults
  export AUTO_ENCRYPT_DISKS=${AUTO_ENCRYPT_DISKS:=1}
  export AUTO_CONFIRM_SETTINGS=${AUTO_CONFIRM_SETTINGS:=1}
  export AUTO_REBOOT=${AUTO_REBOOT:=0}
  export AUTO_USE_DATA_DIR=${AUTO_USE_DATA_DIR:=0}
  export AUTO_CREATE_SERVICE_ACCT=${AUTO_CREATE_SERVICE_ACCT:=0}

  while [[ "${1:-}" != "" ]]
  do
    case $1 in
    -a | --auto | --automatic | --automode | --auto-mode)
      export AUTO_CONFIRM_SETTINGS=0
      export AUTO_REBOOT=1
      ;;
    -c | --confirm | --confirmation)
      export AUTO_CONFIRM_SETTINGS=1
      ;;
    -q | --quiet | --skip-confirm | --skipconfirm | --skip-confirmation | --skipconfirmation | --no-confirm | --noconfirm | --no-confirmation | --noconfirmation)
      export AUTO_CONFIRM_SETTINGS=0
      ;;
    -d | --debug)
      export AUTO_IS_DEBUG=1
      ;;
    --data | --usedata | --use-data)
      export AUTO_USE_DATA_DIR=1
      ;;
    --nodata | --no-data | --nousedata | --no-use-data)
      export AUTO_USE_DATA_DIR=0
      ;;
    --service-acct | --create-service-acct | --svc-acct)
      export AUTO_CREATE_SERVICE_ACCT=1
      ;;
    --no-service-acct | --no-create-service-acct | --no-svc-acct | --nosvc-acct)
      export AUTO_CREATE_SERVICE_ACCT=0
      ;;
    -r | --reboot)
      export AUTO_REBOOT=1
      ;;
    -n | --no-reboot | --noreboot)
      export AUTO_REBOOT=0
      ;;
    -s | --script)
      shift
      CONFIG_SCRIPT_SOURCE=$1
      ;;
    -e | --encrypt | --encrypted)
      export AUTO_ENCRYPT_DISKS=1
      ;;
    -u | --unencrypt | --unencrypted | --not-encrypted | --notencrypted)
      export AUTO_ENCRYPT_DISKS=0
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
  read_input_options "$@"
  set_exports

  download_deb_installer "${script_file}"

  # Now run the script
  bash "${script_file}"
}

main "$@"
EOF
}

download_deb_installer() {
  write_log "In download_deb_installer."

  local script_file=$1

  local script_url="https://raw.githubusercontent.com/brennanfee/linux-bootstraps/main/scripted-installer/debian/deb-install.bash"

  if [[ ! -f "${script_file}" ]]; then
    # To support testing of other versions of the install script (local versions, branches, etc.)
    if [[ "${CONFIG_SCRIPT_SOURCE:=}" != "" ]]; then
      curl -fsSL "${CONFIG_SCRIPT_SOURCE}" --output "${script_file}"
    else
      curl -fsSL "${script_url}" --output "${script_file}"
    fi
  fi
}

run_exports() {
  write_log "In run_exports."

  if [[ ${DEFAULT_KEYMAP} != "${AUTO_KEYMAP}" ]]; then
    export AUTO_KEYMAP=${AUTO_KEYMAP}
  fi
  if [[ ${DEFAULT_LOCALE} != "${AUTO_LOCALE}" ]]; then
    export AUTO_LOCALE=${AUTO_LOCALE}
  fi
  if [[ ${DEFAULT_TIMEZONE} != "${AUTO_TIMEZONE}" ]]; then
    export AUTO_TIMEZONE=${AUTO_TIMEZONE}
  fi

  if [[ ${DEFAULT_INSTALL_OS} != "${AUTO_INSTALL_OS}" ]]; then
    export AUTO_INSTALL_OS=${AUTO_INSTALL_OS}
  fi
  if [[ ${DEFAULT_INSTALL_EDITION} != "${AUTO_INSTALL_EDITION}" ]]; then
    export AUTO_INSTALL_EDITION=${AUTO_INSTALL_EDITION}
  fi
  if [[ ${DEFAULT_KERNEL_VERSION} != "${AUTO_KERNEL_VERSION}" ]]; then
    export AUTO_KERNEL_VERSION=${AUTO_KERNEL_VERSION}
  fi
  if [[ ${DEFAULT_REPO_OVERRIDE_URL} != "${AUTO_REPO_OVERRIDE_URL}" ]]; then
    export AUTO_REPO_OVERRIDE_URL=${AUTO_REPO_OVERRIDE_URL}
  fi

  if [[ ${DEFAULT_HOSTNAME} != "${AUTO_HOSTNAME}" ]]; then
    export AUTO_HOSTNAME=${AUTO_HOSTNAME}
  fi
  if [[ ${DEFAULT_DOMAIN} != "${AUTO_DOMAIN}" ]]; then
    export AUTO_DOMAIN=${AUTO_DOMAIN}
  fi

  if [[ ${DEFAULT_SKIP_PARTITIONING} != "${AUTO_SKIP_PARTITIONING}" ]]; then
    export AUTO_SKIP_PARTITIONING=${AUTO_SKIP_PARTITIONING}
  fi
  if [[ ${DEFAULT_MAIN_DISK} != "${AUTO_MAIN_DISK}" ]]; then
    export AUTO_MAIN_DISK=${AUTO_MAIN_DISK}
  fi
  if [[ ${DEFAULT_SECOND_DISK} != "${AUTO_SECOND_DISK}" ]]; then
    export AUTO_SECOND_DISK=${AUTO_SECOND_DISK}
  fi
  if [[ ${DEFAULT_ENCRYPT_DISKS} != "${AUTO_ENCRYPT_DISKS}" ]]; then
    export AUTO_ENCRYPT_DISKS=${AUTO_ENCRYPT_DISKS}
  fi
  if [[ ${DEFAULT_DISK_PWD} != "${AUTO_DISK_PWD}" ]]; then
    export AUTO_DISK_PWD=${AUTO_DISK_PWD}
  fi

  if [[ ${DEFAULT_ROOT_DISABLED} != "${AUTO_ROOT_DISABLED}" ]]; then
    export AUTO_ROOT_DISABLED=${AUTO_ROOT_DISABLED}
  fi
  if [[ ${DEFAULT_ROOT_PWD} != "${AUTO_ROOT_PWD}" ]]; then
    export AUTO_ROOT_PWD=${AUTO_ROOT_PWD}
  fi
  if [[ ${DEFAULT_CREATE_USER} != "${AUTO_CREATE_USER}" ]]; then
    export AUTO_CREATE_USER=${AUTO_CREATE_USER}
  fi
  if [[ ${DEFAULT_USERNAME} != "${AUTO_USERNAME}" ]]; then
    export AUTO_USERNAME=${AUTO_USERNAME}
  fi
  if [[ ${DEFAULT_USER_PWD} != "${AUTO_USER_PWD}" ]]; then
    export AUTO_USER_PWD=${AUTO_USER_PWD}
  fi
  if [[ ${DEFAULT_USER_SSH_KEY} != "${AUTO_USER_SSH_KEY}" ]]; then
    export AUTO_USER_SSH_KEY=${AUTO_USER_SSH_KEY}
  fi

  if [[ ${DEFAULT_USE_DATA_DIR} != "${AUTO_USE_DATA_DIR}" ]]; then
    export AUTO_USE_DATA_DIR=${AUTO_USE_DATA_DIR}
  fi
  if [[ ${DEFAULT_STAMP_LOCATION} != "${AUTO_STAMP_LOCATION}" ]]; then
    export AUTO_STAMP_LOCATION=${AUTO_STAMP_LOCATION}
  fi
  if [[ ${DEFAULT_CONFIG_MANAGEMENT} != "${AUTO_CONFIG_MANAGEMENT}" ]]; then
    export AUTO_CONFIG_MANAGEMENT=${AUTO_CONFIG_MANAGEMENT}
  fi
  if [[ ${DEFAULT_EXTRA_PACKAGES} != "${AUTO_EXTRA_PACKAGES}" ]]; then
    export AUTO_EXTRA_PACKAGES=${AUTO_EXTRA_PACKAGES}
  fi
  if [[ ${DEFAULT_EXTRA_PREREQ_PACKAGES} != "${AUTO_EXTRA_PREREQ_PACKAGES}" ]]; then
    export AUTO_EXTRA_PREREQ_PACKAGES=${AUTO_EXTRA_PREREQ_PACKAGES}
  fi

  if [[ ${DEFAULT_BEFORE_SCRIPT} != "${AUTO_BEFORE_SCRIPT}" ]]; then
    export AUTO_BEFORE_SCRIPT=${AUTO_BEFORE_SCRIPT}
  fi
  if [[ ${DEFAULT_AFTER_SCRIPT} != "${AUTO_AFTER_SCRIPT}" ]]; then
    export AUTO_AFTER_SCRIPT=${AUTO_AFTER_SCRIPT}
  fi
  if [[ ${DEFAULT_FIRST_BOOT_SCRIPT} != "${AUTO_FIRST_BOOT_SCRIPT}" ]]; then
    export AUTO_FIRST_BOOT_SCRIPT=${AUTO_FIRST_BOOT_SCRIPT}
  fi

  if [[ ${DEFAULT_CONFIRM_SETTINGS} != "${AUTO_CONFIRM_SETTINGS}" ]]; then
    export AUTO_CONFIRM_SETTINGS=${AUTO_CONFIRM_SETTINGS}
  fi
  if [[ ${DEFAULT_REBOOT} != "${AUTO_REBOOT}" ]]; then
    export AUTO_REBOOT=${AUTO_REBOOT}
  fi
}

execute_now() {
  write_log "In execute_now."

  local script_file
  script_file="/tmp/deb-install.bash"
  local proceed=0

  # Confirm they want to do a local installation
  print_section "Proceed with local installation"
  print_section_info "Are you ABSOLUTELY CERTAIN that you want to proceed with a LOCAL installation given the values you provided during this interactive session?  Please be aware that files and file systems may be altered in the process which could result in LOSS OF DATA."

  local yes_no=('No' 'Yes')
  local option
  select option in "${yes_no[@]}"; do
    get_exit_code contains_element "${option}" "${yes_no[@]}"
    if [[ ${EXIT_CODE} == "0" ]]; then
      break
    else
      invalid_option
    fi
  done

  option=$(echo "${option}" | tr "[:upper:]" "[:lower:]")
  case "${option}" in
  yes)
    proceed=1
    ;;
  no)
    proceed=0
    ;;
  *)
    error_msg "Invalid selection for proceed with location installation."
    ;;
  esac

  write_log "Should proceed with local installation: ${proceed}"

  if [[ "${proceed}" == "1" ]]; then
    run_exports

    download_deb_installer "${script_file}"

    # Now run the script
    bash "${script_file}"
  fi
}

prompts_for_options() {
  ask_for_keymap
  ask_for_locale
  ask_for_timezone

  ask_for_os_to_install
  ask_for_edition_to_install
  ask_for_kernel_version
  ask_for_repo_override_url

  ask_for_hostname
  ask_for_domain

  ask_should_skip_partitioning
  ask_for_main_disk
  ask_for_second_disk
  ask_should_encrypt_disks
  ask_for_disk_password

  ask_should_enable_root
  ask_for_root_password
  ask_should_create_user
  ask_for_user_name
  ask_for_user_password
  ask_for_user_ssh_key

  ask_should_use_data_directory
  ask_override_stamp_location
  ask_install_configuration_management
  ask_install_extra_packages
  ask_install_extra_prereq_packages

  ask_for_before_script
  ask_for_after_script
  ask_for_first_boot_script

  ask_about_settings_confirmation
  ask_about_auto_reboot
}

### END: Prompts & User Interaction

main() {
  export DEBIAN_FRONTEND=noninteractive
  # Setup local environment
  system_verifications
  install_prereqs
  setup_installer_environment

  welcome_screen
  prompts_for_options
  print_summary
  ask_export_or_execute

  case "${SELECTED_ACTION}" in
  export)
    export_config
    ;;
  execute)
    execute_now
    ;;
  exit)
    noop
    ;;
  *)
    error_msg "Invalid selection script action."
    ;;
  esac
}

main "$@"
