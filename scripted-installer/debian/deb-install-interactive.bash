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

### Start: Data

SCRIPT_AUTHOR="Brennan Fee"
SCRIPT_LICENSE="MIT License"
SCRIPT_VERSION="0.5"
SCRIPT_DATE="2022-11-15"

# The supported target OSes to be installed
SUPPORTED_OSES=('debian' 'ubuntu')
SUPPORTED_OSES_DISPLAY=('Debian' 'Ubuntu')

# Disk to types to accept as install locations for the auto selection methods
BLOCK_DISKS="3,8,9,22,33,34,65,66,67,202,253,254,259"

### End: Data

### Start: Constants & Global Variables

# Should only be on during testing.  Primarly this turns on the output of passwords.
IS_DEBUG=${AUTO_IS_DEBUG:=0}

# Paths
WORKING_DIR=$(pwd)
LOG="${WORKING_DIR}/interactive-install.log"
[[ -f ${LOG} ]] && rm -f "${LOG}"
INSTALL_DATE=$(date -Is)
echo "Start log: ${INSTALL_DATE}" >> "${LOG}"
echo "------------" >> "${LOG}"

# Console font size, I pre-configure the console font to enlarge it which shoudl work better on higher resolution screens.
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
DEFAULT_TIMEZONE="America/Chicago"  # Suck it east and west coast!  ;-)

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

DEFAULT_USE_DATA_FOLDER="0"
DEFAULT_STAMP_FOLDER=""

DEFAULT_CONFIG_MANAGEMENT="none"
DEFAULT_EXTRA_PACKAGES=""

DEFAULT_BEFORE_SCRIPT=""
DEFAULT_AFTER_SCRIPT=""
DEFAULT_FIRST_BOOT_SCRIPT=""

DEFAULT_CONFIRM_SETTINGS="0"
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

AUTO_USE_DATA_FOLDER="${DEFAULT_USE_DATA_FOLDER}"
AUTO_STAMP_FOLDER="${DEFAULT_STAMP_FOLDER}"

AUTO_CONFIG_MANAGEMENT="${DEFAULT_CONFIG_MANAGEMENT}"
AUTO_EXTRA_PACKAGES="${DEFAULT_EXTRA_PACKAGES}"

AUTO_BEFORE_SCRIPT="${DEFAULT_BEFORE_SCRIPT}"
AUTO_AFTER_SCRIPT="${DEFAULT_AFTER_SCRIPT}"
AUTO_FIRST_BOOT_SCRIPT="${DEFAULT_FIRST_BOOT_SCRIPT}"

AUTO_CONFIRM_SETTINGS="${DEFAULT_CONFIRM_SETTINGS}"
AUTO_REBOOT="${DEFAULT_REBOOT}"

### END: Options

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
  write_log ""
}

write_log_spacer() {
  write_log "------"
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
  echo -e "SECTION: ${1}" >> "${LOG}"
  print_line
  blank_line
}

print_section_info() {
  T_COLS=$(tput cols)
  echo -e "${BOLD}$1${RESET}\n" | fold -sw $((T_COLS - 18)) | sed 's/^/\t/'
  print_line
  blank_line
  echo -e "SECTION-INFO: ${1}" >> "${LOG}"
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
  echo -e "STATUS: ${1}" >> "${LOG}"
}

print_info() {
  T_COLS=$(tput cols)
  echo -e "${BOLD}$1${RESET}" | fold -sw $((T_COLS - 1))
  echo -e "INFO: ${1}" >> "${LOG}"
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
  if [[ ${1:=} == "" ]]
  then
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
    set -e;
    # ...and run the function
    "$@"
  )
  EXIT_CODE=$?
  # And finally turn errexit back on in the current shell
  set -e
}

contains_element() {
  #check if an element exist in a string
  for e in "${@:2}"
  do
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
  if [[ "${user_id}" != "0" ]]
  then
    error_msg "ERROR! You must execute the script as the 'root' user."
  fi
}

check_netcheck_network_connection() {
  print_info "Checking network connectivity..."

  # Check localhost first (if network stack is up at all)
  if ping -q -w 3 -c 2 localhost &> /dev/null
  then
    # Test the gateway
    gateway_ip=$(ip r | grep default | awk 'NR==1 {print $3}')
    if ping -q -w 3 -c 2 "${gateway_ip}" &> /dev/null
    then
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
  print_info "Installing prerequisites"
  DEBIAN_FRONTEND=noninteractive apt-get -y -q update || true
  DEBIAN_FRONTEND=noninteractive apt-get -y -q full-upgrade || true
  DEBIAN_FRONTEND=noninteractive apt-get -y -q autoremove || true

  # Things all systems need (reminder these are being installed to the installation environment, not the target machine)
  print_status "    Installing common prerequisites"
  # TODO: Clean thlist of pre-reqs
  local_install vim laptop-detect console-data locales fbset

  #Original: local_install vim parted bc cryptsetup lvm2 xfsprogs laptop-detect ntp console-data locales fbset
}

setup_installer_environment() {
  # Locale
  local current_locale
  current_locale=$(localectl status | grep -i 'system locale' | cut -d: -f 2 | cut -d= -f 2)
  if [[ ${current_locale} != "${AUTO_LOCALE}" ]]
  then
    localectl set-locale "${AUTO_LOCALE}"
    export LC_ALL="${AUTO_LOCALE}"
  fi

  # Keymap
  loadkeys "${AUTO_KEYMAP}"

  # Resolution
  local detected_virt
  detected_virt=$(systemd-detect-virt || true)
  if [[ ${detected_virt} == "oracle" ]]
  then
    fbset -xres 1280 -yres 720 -depth 32
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
  print_status "Script can be cancelled at any time with CTRL+C"
  blank_line
  pause_output
}

ask_for_keymap() {
  write_log "In ask for keymap."

  print_section "Keymap"
  print_section_info "Pick a keymap for the machine.  Press enter to accept the default."
  local input
  read -rp "Keymap [${AUTO_KEYMAP}]: " input
  if [[ ${input} != "" ]]
  then
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
  if [[ ${input} != "" ]]
  then
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

  # TODO: Validate

  write_log "Timezone to use: ${AUTO_TIMEZONE}"
}

ask_for_os_to_install() {
  write_log "In ask for os to install."

  print_section "OS To Install"
  print_section_info "Pick an OS to install."
  local input_os
  select input_os in "${SUPPORTED_OSES_DISPLAY[@]}"
  do
    get_exit_code contains_element "${input_os}" "${SUPPORTED_OSES_DISPLAY[@]}"
    if [[ ${EXIT_CODE} == "0" ]]
    then
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
  if [[ ${EXIT_CODE} != "0" ]]
  then
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
  if [[ ! ${EXIT_CODE} == "0" ]]
  then
    print_section "Kernel Version To Install"
    print_section_info "Pick a Kernel Version to install.  Note that if the backport kernel is requested but it is not available, the default kernel will be installed."

    local options=('default' 'backport')

    local input_version
    select input_version in "${options[@]}"
    do
      get_exit_code contains_element "${input_version}" "${options[@]}"
      if [[ ${EXIT_CODE} == "0" ]]
      then
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
  print_section_info "Pick a Kernel Version to install.  Note that the installer will regressively fall back if the requested kernel edition is not available.  If hwe-edge is requested but only hwe is avialable, you will get hwe.  If neither are aviable, the default kernel will be installed."

  local options=('default' 'hwe' 'hwe-edge')

  local input_version
  select input_version in "${options[@]}"
  do
    get_exit_code contains_element "${input_version}" "${options[@]}"
    if [[ ${EXIT_CODE} == "0" ]]
    then
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
  select option in "${yes_no[@]}"
  do
    get_exit_code contains_element "${option}" "${yes_no[@]}"
    if [[ ${EXIT_CODE} == "0" ]]
    then
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

  if [[ ${AUTO_SKIP_PARTITIONING} == 1 ]]
  then
    ask_for_main_disk_skipped_partition
  else
    print_section "Main Disk Selection"
    print_section_info "How do you want to determine the main\root disk to install? Select 'Smallest' (the default) to auto-select the smallest disk, 'Largest' to auto-select the largest disk, or 'Direct' to enter a device path manually (such as /dev/sda)."

    local disk_options=('Smallest' 'Largest' 'Direct')
    local option
    select option in "${disk_options[@]}"
    do
      get_exit_code contains_element "${option}" "${disk_options[@]}"
      if [[ ${EXIT_CODE} == "0" ]]
      then
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
        while :
        do
          blank_line
          local input
          read -rp "Enter in the device: " input
          if [[ ${input} == /dev/* ]]
          then
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

  while :
  do
    blank_line
    local input
    read -rp "Enter in the device: " input
    if [[ ${input} == /dev/* ]]
    then
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
  if [[ ${AUTO_SKIP_PARTITIONING} == 0 ]]
  then
    print_section "Second Disk Selection"
    print_section_info "What to do if the system has a second (or more) disks.  Select 'Ignore' (the default) to ignore the other disks and only use the main disk, 'Smallest' to auto-select the smallest disk (or next smallest, after the main disk), 'Largest' to auto-select the largest disk (or next largest, after the main disk), or 'Direct' to type in a device to use manually."

    local disk_options=('Ignore' 'Smallest' 'Largest' 'Direct')
    local option
    select option in "${disk_options[@]}"
    do
      get_exit_code contains_element "${option}" "${disk_options[@]}"
      if [[ ${EXIT_CODE} == "0" ]]
      then
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
        while :
        do
          blank_line
          local input
          read -rp "Enter in the device: " input
          if [[ ${input} == /dev/* ]]
          then
            if [[ ${input} == "${AUTO_MAIN_DISK}" ]]
            then
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
  if [[ ${AUTO_SKIP_PARTITIONING} == 0 ]]
  then
    print_section "Disk Encryption"
    print_section_info "Should the disks be encrypted?"
    local yes_no=('Yes' 'No')
    local option
    select option in "${yes_no[@]}"
    do
      get_exit_code contains_element "${option}" "${yes_no[@]}"
      if [[ ${EXIT_CODE} == "0" ]]
      then
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
  if [[ ${AUTO_ENCRYPT_DISKS} == 1 ]]
  then
    print_section "Disk Passphrase"
    print_section_info "How do you want the disk passphrase to be selected.  You can select 'File' (the default) and an randomly generated encryption file will be used, 'Path' and you can provide a path to a file to use, or 'URL' for a downloadable file to use.  These three options are best used for automated environments where a password entry for boot would be inconvenient yet encrypting the disks is still desired.  It also allows changing the encryption key setup later on after the machine is bootstrapped, which is highly secure given the default setup does not secure the key files.  Lastly, you can select 'Passphrase' to enter a passhprase to use.  Please note that using 'Passphrase' may break any automations in the system configuration as entering the password manually will be required at boot."

    local encryption_options=('File' 'Path' 'URL' 'Passphrase')
    local option
    select option in "${encryption_options[@]}"
    do
      get_exit_code contains_element "${option}" "${encryption_options[@]}"
      if [[ ${EXIT_CODE} == "0" ]]
      then
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
        while :
        do
          blank_line
          local input
          read -rp "Enter in the file: " input
          if [[ ${input} == /* ]]
          then
            AUTO_DISK_PWD=${input}
            break
          else
            invalid_option "You must input a full path to the file, releative paths are not supported."
          fi
        done
        ;;
      url)
        while :
        do
          blank_line
          local input
          read -rp "Enter in the URL: " input
          if [[ ${input} == http://* || ${input} == https:// ]]
          then
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
  select option in "${yes_no[@]}"
  do
    get_exit_code contains_element "${option}" "${yes_no[@]}"
    if [[ ${EXIT_CODE} == "0" ]]
    then
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
  select option in "${yes_no[@]}"
  do
    get_exit_code contains_element "${option}" "${yes_no[@]}"
    if [[ ${EXIT_CODE} == "0" ]]
    then
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
  if [[ ${username} == "" ]]
  then
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
  if [[ ${username} == "" ]]
  then
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

print_summary() {
  print_title
  print_summary_header "Install Summary (Part 1)" "Below is a summary of your selections.  Review them carefully."
  print_line

  print_status "The selected keymap is '${AUTO_KEYMAP}', locale is '${AUTO_LOCALE}', and the selected timezone is '${AUTO_TIMEZONE}'."

  print_status "The distribution to install is '${AUTO_INSTALL_OS}', '${AUTO_INSTALL_EDITION}' edition."

  print_status "The kernel version to install, if available, is '${AUTO_KERNEL_VERSION}'."

  if [[ ${AUTO_REPO_OVERRIDE_URL} == "" ]]
  then
    print_status "The installation repository URL will not be overriden."
  else
    print_status "The installation repository will be overriden, the URL to use is '${AUTO_REPO_OVERRIDE_URL}'."
  fi
  blank_line

  local domain_info
  if [[ ${AUTO_DOMAIN} != "" ]]
  then
    domain_info="The domain selected is '${AUTO_DOMAIN}'."
  else
    domain_info="No domain was provided."
  fi
  if [[ ${AUTO_HOSTNAME} == "" ]]
  then
    print_status "The hostname will be auto-generated. ${domain_info}"
  else
    print_status "The hostname selected is '${AUTO_HOSTNAME}'. ${domain_info}"
  fi
  blank_line

  if [[ ${AUTO_SKIP_PARTITIONING} == "1" ]]
  then
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

    if [[ ${AUTO_ENCRYPT_DISKS} == "1" ]]
    then
      print_status "The disks will be encrypted.  Encryption method is: '${encryption_method}'."
    else
      print_status "The disks will NOT be encrypted."
    fi
  fi
  blank_line

  if [[ ${AUTO_ROOT_DISABLED} == "1" ]]
  then
    print_status "The root account will be disabled."
  else
    print_status "The root account will be activated."
  fi

  if [[ ${AUTO_CREATE_USER} == "1" ]]
  then
    if [[ ${AUTO_USERNAME} == "" ]]
    then
      print_status "A default user '${AUTO_INSTALL_OS}' will be created and granted sudo permissions."
    else
      print_status "User '${AUTO_USERNAME}' will be created and granted sudo permissions."
    fi
  else
    print_status "User creation was disabled."
  fi
  blank_line

  pause_output
}

prompts_for_options(){
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
}

### END: Prompts & User Interaction

main() {
  export DEBIAN_FRONTEND=noninteractive
  # Setup local environment
  system_verifications
#  install_prereqs
  setup_installer_environment

  welcome_screen
  prompts_for_options
  print_summary
  #ask_export_or_execute

  error_msg "ERROR: This script is not yet implemented."
}

main
