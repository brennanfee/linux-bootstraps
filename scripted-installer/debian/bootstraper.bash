#!/usr/bin/env bash
# Author: Brennan A. Fee
# License: MIT License
#
# This script uses the deb-install script to install Debian/Ubuntu the "Arch"
# way.  This config script sets some values for a specific type of installation
# and then automatically calls the deb-install script.  Optionally, it allows
# using an external script to set some of the values.
#
# Short URL:
# Github URL:
#

SCRIPT_AUTHOR="Brennan Fee"
SCRIPT_LICENSE="MIT License"
SCRIPT_VERSION="1.8"
SCRIPT_DATE="2024-08-10"

############ START: Generic Print Methods

print_line() {
  local T_COLS
  T_COLS=$(tput cols)
  printf "%${T_COLS}s\n" | tr ' ' '-'
}

print_blank_line() {
  echo ""
}

print_msg() {
  local T_COLS
  local RESET
  RESET="$(tput sgr0)"
  T_COLS=$(($(tput cols) - 1))
  echo -e "$1${RESET}" | fold -sw "${T_COLS}"
}

print_debug() {
  print_msg "DEBUG: $1"
}

print_bold() {
  local T_COLS
  local RESET
  local BOLD
  RESET="$(tput sgr0)"
  BOLD="$(tput bold)"
  T_COLS=$(($(tput cols) - 1))
  echo -e "${BOLD}$1${RESET}" | fold -sw "${T_COLS}"
}

print_error() {
  local RED
  local RESET
  local T_COLS
  RESET="$(tput sgr0)"
  RED="$(tput setaf 1)"
  T_COLS=$(($(tput cols) - 1))
  echo -e "${RED}$1${RESET}\n" | fold -sw "${T_COLS}"
}

error_msg() {
  print_error "$1"
  exit 1
}

############ END: Generic Print Methods

#### START: Array Utilities

# Used to call a function or command and rather than fail due to 'set -e' in the
# current shell, grab its exit code.  This is useful\necessary when you want to
# gracefully handle the result of a command that would otherwise stop execution
# of the script due to 'set -e' being turned on.
#
# Usage: Call this function just prior to a bash function or command you wish to
# capture the exit code for.  Inputs for the second function can be passed as
# usual and they will flow through to the execution of the command.
#
# get_exit_code some_function input1 input2
#
# Afterward you can then check the ${EXIT_CODE} variable and handle it however
# you wish.
function get_exit_code() {
  EXIT_CODE=0
  # We first disable errexit in the current shell
  set +e
  (
    # Then we set it again inside a subshell
    set -e
    # ...and run the function
    "$@"
  )
  # shellcheck disable=2034
  EXIT_CODE=$?
  # And finally turn errexit back on in the current shell
  set -e
}

# Check if a string exists in an array of elements\strings
#
# Say you have an array like:  DISTROS=('debian' 'ubuntu' 'arch')
# If you wanted to verify whether the string 'debian' exists in that array, you
# could use the following:
#
# get_exit_code contains_element "debian" "${DISTROS[@]}"
# if [[ ${EXIT_CODE} -eq 0 ]]
# then
#   <string does exist in array, code goes here>
# fi
#
function contains_element() {
  for e in "${@:2}"; do
    [[ ${e} == "$1" ]] && break
  done
}

#### END: Array Utilities

############ START: Help and Output

print_title() {
  clear
  local text="Deb-Install Automated Bootstrapper - Author: ${SCRIPT_AUTHOR} - "
  text+="License: ${SCRIPT_LICENSE}"
  print_bold "${text}"
  print_line
}

show_help() {
  local l="Deb-Install Bootstraper Help -- Script version: ${SCRIPT_VERSION} "
  l+="- Script date: ${SCRIPT_DATE}"
  print_msg "$l"
  print_blank_line
  print_msg "Example:  bootstraper.bash (configuration) (os edition) (flags/options)"
  print_blank_line
  l="Configuration is optional and can be one of 'default', 'vagrant', 'vm', 'homelab', "
  l+="'vmhomelab', and 'external'.  The default is 'default'. These configurations serve as "
  l+="pre-set groups of settings based on a common target type of system to be initialized. "
  l+="For instance, the vagrant configuration assumes vm usage (and so skips disk encryption) "
  l+="and creates a 'vagrant' user as the main user.  All of the values initialized with a "
  l+="configuration can be overridden by flags or options that follow.  For the 'external' "
  l+="configuration the next parameter must be a URL that points to a script that will set "
  l+="the desired options (using exported environment variables). The script will be downloaded "
  l+="and sourced before the rest of the options are processed. Example: bootstraper.bash "
  l+="external https://tinyurl.com/mysettings"
  print_msg "$l"
  print_blank_line
  l="OS Edition is optional and can be any of 'stable', 'backports', 'testing', or 'sid' "
  l+="for Debian and 'lts', 'ltshwe', 'ltsedge', or 'rolling' for Ubuntu.  It is also possible "
  l+="to pass in a codename for a release, such as 'bookworm' or 'jammy', but then the following "
  l+="parameter must be the target distribution (only 'debian' and 'ubuntu' are supported.) "
  l+="Example: bootstraper.bash vagrant bookworm debian"
  print_msg "$l"
  print_blank_line
  l="Options are all passed as flags (-{short option}, --{long option}), some are mutually "
  l+="exclusive and in those cases the last one passed in wins.  For a list of the options "
  l+="run this script again with 'options' as the configuration or --options as a flag."
  print_msg "$l"
  print_blank_line
  l="Lastly, all of these settings and flags are simply setting up the environment variable "
  l+="exports that are read by the deb-install.bash script (all starting with 'AUTO_'). "
  l+="Within this script they are all initialized by default from any environment variables "
  l+="that were already set prior to calling this script.  This way any you set before calling "
  l+="this script will 'pass through' as the defaults, which can then be overridden by the "
  l+="selected configuration, and finally overridden by the flags."
  print_msg "$l"
  print_blank_line
  exit 0
}

show_options() {
  local l="Deb-Install Bootstraper Help -- Script version: ${SCRIPT_VERSION} "
  l+="- Script date: ${SCRIPT_DATE}"
  print_msg "$l"
  print_blank_line
  l="Most options allow a 'no' option to turn the option off rather than on. "
  l+="Simply pass --no-{option} or --no{option} instead.  The 'auto', 'single-disk', "
  l+="'dual-disk', and 'script' options are the only ones without the 'no' variants. "
  l+="To use the 'no' option you cannot use the short variant for the option name."
  print_msg "$l"
  print_blank_line
  print_msg "Options:"
  print_blank_line
  print_msg "  --auto: Auto-mode, no confirmations and auto-reboots the machine after install."
  print_msg "      Aliases: -a, --automatic, --automode, --auto-mode"
  print_msg "  --confirm: Ask for option confirmation on install. Aliases: -c, --confirmation"
  print_msg "  --reboot: Reboot the machine automatically at end of install. Alias: -r"
  print_msg "  --debug: Debug mode, run the install script in debug mode. Alias: -d"
  print_msg "  --single-disk: Single disk machine configuration. Alias: --single"
  print_msg "  --dual-disk: Dual disk machine configuration. Alias: --dual"
  print_msg "  --encrypt: Encrypt the disks. Aliases: -e, --encrypted"
  print_msg "  --enable-root: Enable and configure the root account."
  print_msg "  --data: Configure a data directory (not commonly used)."
  print_msg "      Aliases: --usedata, --use-data"
  print_msg "  --service-acct: Configure a service account (not commonly used)."
  print_msg "      Aliases: --create-service-acct, --svc-acct"
  print_blank_line
  local l="Finally, a --script option is available that is used in advanced and test scenario's "
  l+="to override which deb-installer script to use.  It is passed like: --script <path to script>"
  print_msg "$l"
  print_blank_line
  exit 0
}

print_options() {
  print_blank_line
  print_bold "CONFIGURATION='${CONFIGURATION}'"
  if [[ "${CONFIGURATION}" == "external" ]]; then
    print_bold "EXTERNAL URL='${CONFIGURATION_URL}'"
  fi

  print_bold "AUTO_INSTALL_EDITION='${AUTO_INSTALL_EDITION}'"
  print_bold "AUTO_INSTALL_OS='${AUTO_INSTALL_OS}'"
  print_bold "AUTO_KERNEL_VERSION='${AUTO_KERNEL_VERSION}'"

  print_blank_line

  print_bold "AUTO_MAIN_DISK='${AUTO_MAIN_DISK}'"
  print_bold "AUTO_SECOND_DISK='${AUTO_SECOND_DISK}'"
  print_bold "AUTO_ENCRYPT_DISKS='${AUTO_ENCRYPT_DISKS}'"

  print_blank_line

  print_bold "AUTO_DOMAIN='${AUTO_DOMAIN}'"

  print_blank_line

  print_bold "AUTO_ROOT_DISABLED='${AUTO_ROOT_DISABLED}'"
  print_bold "AUTO_CREATE_USER='${AUTO_CREATE_USER}'"
  print_bold "AUTO_USERNAME='${AUTO_USERNAME}'"
  print_bold "AUTO_USER_PWD='${AUTO_USER_PWD}'"
  print_bold "AUTO_CREATE_SERVICE_ACCT='${AUTO_CREATE_SERVICE_ACCT}'"
  print_bold "AUTO_SERVICE_ACCT_SSH_KEY='${AUTO_SERVICE_ACCT_SSH_KEY}'"
  print_bold "AUTO_USE_DATA_DIR='${AUTO_USE_DATA_DIR}'"

  print_blank_line

  print_bold "AUTO_CONFIRM_SETTINGS='${AUTO_CONFIRM_SETTINGS}'"
  print_bold "AUTO_REBOOT='${AUTO_REBOOT}'"

  print_blank_line

  print_bold "AUTO_IS_DEBUG='${AUTO_IS_DEBUG}'"
}

############ END: Help and Output

CONFIGURATION="default"
CONFIGURATION_URL=""
PARAMETER_SHIFTS=0
INTERACTIVE=0

load_defaults() {
  export AUTO_INSTALL_EDITION="${AUTO_INSTALL_EDITION:=stable}"
  export AUTO_INSTALL_OS="${AUTO_INSTALL_OS:=debian}"
  export AUTO_KERNEL_VERSION="${AUTO_KERNEL_VERSION:=backports}"

  export AUTO_MAIN_DISK="${AUTO_MAIN_DISK:=smallest}"
  export AUTO_SECOND_DISK="${AUTO_SECOND_DISK:=ignore}"
  export AUTO_ENCRYPT_DISKS="${AUTO_ENCRYPT_DISKS:=0}"

  export AUTO_DOMAIN="${AUTO_DOMAIN:=}"

  export AUTO_ROOT_DISABLED="${AUTO_ROOT_DISABLED:=0}"
  export AUTO_CREATE_USER="${AUTO_CREATE_USER:=0}"
  export AUTO_USERNAME="${AUTO_USERNAME:=}"
  export AUTO_USER_PWD="${AUTO_USER_PWD:=}"
  export AUTO_CREATE_SERVICE_ACCT="${AUTO_CREATE_SERVICE_ACCT:=0}"
  export AUTO_SERVICE_ACCT_SSH_KEY="${AUTO_SERVICE_ACCT_SSH_KEY:=}"

  export AUTO_USE_DATA_DIR="${AUTO_USE_DATA_DIR:=0}"

  export AUTO_CONFIRM_SETTINGS="${AUTO_CONFIRM_SETTINGS:=1}"
  export AUTO_REBOOT="${AUTO_REBOOT:=0}"

  export AUTO_IS_DEBUG="${AUTO_IS_DEBUG:=0}"
}

process_positional_arguments() {
  if [[ "$1" == "help" || "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
  fi
  if [[ "$1" == "options" || "$1" == "--options" ]]; then
    show_options
  fi

  local supported_editions=("stable" "backport" "backports" "testing" "sid" "lts" "ltshwe" "ltsedge" "rolling")

  ## Configuration
  if [[ "$1" != "" ]]; then
    CONFIGURATION="$1"
    PARAMETER_SHIFTS=$((PARAMETER_SHIFTS + 1))

    local supported_configs=("default" "defaults" "vagrant" "vm" "homelab" "vmhomelab" "external")
    get_exit_code contains_element "${CONFIGURATION}" "${supported_configs[@]}"
    if [[ ! "${EXIT_CODE}" == "0" ]]; then
      local l="Value read as configuration '${CONFIGURATION}' is not valid, try again with "
      l+="a supported value."
      print_error "$l"
      show_help
    fi

    if [[ "${CONFIGURATION}" == "external" ]]; then
      shift
      PARAMETER_SHIFTS=$((PARAMETER_SHIFTS + 1))

      CONFIGURATION_URL="$1"
      local is_error="0"

      if [[ "${CONFIGURATION_URL}" == "" || "${CONFIGURATION_URL}" =~ ^"-" ]]; then
        is_error="1"
      fi

      get_exit_code contains_element "${CONFIGURATION_URL}" "${supported_editions[@]}"
      if [[ "${EXIT_CODE}" == "0" ]]; then
        is_error="1"
      fi

      if [[ "${CONFIGURATION_URL}" == "debian" || "${CONFIGURATION_URL}" == "ubuntu" ]]; then
        is_error="1"
      fi

      if [[ "${is_error}" == "1" ]]; then
        local l="When using the 'external' setting, you must provide a URL to a script "
        l+="that will be used to set the environment variable defaults."
        print_error "$l"
        show_help
      fi
    fi
  fi

  shift

  ## OS Edition
  if [[ ! ("$1" =~ ^"-" || "$1" == "") ]]; then
    local edition="$1"
    local os="debian"
    PARAMETER_SHIFTS=$((PARAMETER_SHIFTS + 1))

    get_exit_code contains_element "${edition}" "${supported_editions[@]}"
    if [[ ! "${EXIT_CODE}" == "0" ]]; then
      shift
      PARAMETER_SHIFTS=$((PARAMETER_SHIFTS + 1))

      os="$1"
      if [[ "${os}" != "debian" && "${os}" != "ubuntu" ]]; then
        print_error "For an edition based on a code name, you must pass the OS as the second parameter."
        show_help
      fi

      export AUTO_KERNEL_VERSION="default"
    else
      case "${edition}" in
        "stable" | "testing" | "sid")
          os="debian"
          export AUTO_KERNEL_VERSION="default"
          ;;
        "backport" | "backports")
          os="debian"
          edition="stable"
          export AUTO_KERNEL_VERSION="backports"
          ;;
        "lts" | "rolling")
          os="ubuntu"
          export AUTO_KERNEL_VERSION="default"
          ;;
        "ltshwe")
          os="ubuntu"
          edition="lts"
          export AUTO_KERNEL_VERSION="hwe"
          ;;
        "ltsedge")
          os="ubuntu"
          edition="lts"
          export AUTO_KERNEL_VERSION="hwe-edge"
          ;;
        *)
          noop
          ;;
      esac
    fi
  fi

  export AUTO_INSTALL_OS="${os}"
  export AUTO_INSTALL_EDITION="${edition}"
}

process_configuration() {
  case ${CONFIGURATION} in
    default | defaults)
      ## do nothing
      ;;
    vagrant)
      export AUTO_ENCRYPT_DISKS=0

      export AUTO_CREATE_USER=1
      export AUTO_USERNAME="vagrant"
      export AUTO_USER_PWD="vagrant"

      export AUTO_MAIN_DISK="smallest"
      export AUTO_SECOND_DISK="ignore"
      export AUTO_ENCRYPT_DISKS=0
      ;;
    vm)
      export AUTO_MAIN_DISK="smallest"
      export AUTO_SECOND_DISK="ignore"
      export AUTO_ENCRYPT_DISKS=0
      ;;
    homelab)
      process_from_external "https://tinyurl.com/brennan-homelab"
      ;;
    vmhomelab)
      process_from_external "https://tinyurl.com/brennan-vmhomelab"
      ;;
    external)
      process_from_external "$CONFIGURATION_URL"
      ;;
    *)
      error_msg "Unknown configuration: '${CONFIGURATION}'"
      ;;
  esac
}

process_from_external() {
  local script_url="$1"
  local script_file="/tmp/external_config"
  local downloaded=0

  if [[ -f "${script_url}" ]]; then
    script_file="${script_url}"
  elif [[ ! -f "${script_file}" ]]; then
    wget -O "${script_file}" "${script_url}"
    downloaded=1
  fi

  # Source the script
  # print_debug "Sourcing script"
  # shellcheck source=/dev/null
  source "${script_file}"

  # Remove it
  if [[ "${downloaded}" == "1" ]]; then
    rm "${script_file}"
  fi
}

process_options() {
  for ((i = 0; i < PARAMETER_SHIFTS; i++)); do
    shift
  done

  # Loop the rest of the options, setting the exports as we go
  while [[ "${1:-}" != "" ]]; do
    case $1 in
      -h | --help)
        show_help
        ;;
      --options)
        show_options
        ;;
      -a | --auto | --automatic | --automode | --auto-mode)
        export AUTO_CONFIRM_SETTINGS=0
        export AUTO_REBOOT=1
        ;;
      --single-disk | --single)
        export AUTO_MAIN_DISK="smallest"
        export AUTO_SECOND_DISK="ignore"
        ;;
      --dual-disk | --dual)
        export AUTO_MAIN_DISK="smallest"
        export AUTO_SECOND_DISK="largest"
        ;;
      -c | --confirm | --confirmation)
        export AUTO_CONFIRM_SETTINGS=1
        ;;
      --noconfirm | --no-confirm | --noconfirmation | --no-confirmation)
        export AUTO_CONFIRM_SETTINGS=0
        ;;
      -r | --reboot)
        export AUTO_REBOOT=1
        ;;
      --noreboot | --no-reboot)
        export AUTO_REBOOT=0
        ;;
      -d | --debug)
        export AUTO_IS_DEBUG=1
        ;;
      --nodebug | --no-debug)
        export AUTO_IS_DEBUG=0
        ;;
      -e | --encrypt | --encrypted)
        export AUTO_ENCRYPT_DISKS=1
        ;;
      --noencrypt | --no-encrypt | --noencryption | --no-encryption)
        export AUTO_ENCRYPT_DISKS=0
        ;;
      --enable-root)
        export AUTO_ROOT_DISABLED=0
        ;;
      --noenable-root | --no-enable-root | --disable-root)
        export AUTO_ROOT_DISABLED=1
        ;;
      --data | --usedata | --use-data)
        export AUTO_USE_DATA_DIR=1
        ;;
      --nodata | --no-data | --nousedata | --no-usedata | --nouse-data | --no-use-data)
        export AUTO_USE_DATA_DIR=0
        ;;
      --service-acct | --create-service-acct | --svc-acct)
        export AUTO_CREATE_SERVICE_ACCT=1
        ;;
      --noservice-acct | --no-service-acct | --nocreate-service-acct | --no-create-service-acct | --nosvc-acct | --no-svc-acct)
        export AUTO_CREATE_SERVICE_ACCT=0
        ;;
      --i | --interactive)
        INTERACTIVE=1
        ;;
      *)
        error_msg "Unknown option: '$1'"
        ;;
    esac

    shift
  done
}

download_deb_installer() {
  local script_file=$1

  local script_url="https://raw.githubusercontent.com/brennanfee/linux-bootstraps/main/scripted-installer/debian/deb-install.bash"
  if [[ "${INTERACTIVE}" == 1 ]]; then
    local script_url="https://raw.githubusercontent.com/brennanfee/linux-bootstraps/main/scripted-installer/debian/deb-install-interactive.bash"
  fi

  if [[ ! -f "${script_file}" ]]; then
    # To support testing of other versions of the install script (local versions, branches, etc.)
    if [[ "${CONFIG_SCRIPT_SOURCE:=}" != "" ]]; then
      wget -O "${script_file}" "${CONFIG_SCRIPT_SOURCE}"
    else
      wget -O "${script_file}" "${script_url}"
    fi
  fi
}

main() {
  print_title

  load_defaults
  process_positional_arguments "$@"

  process_configuration

  process_options "$@"

  print_options

  local script_file
  script_file="/tmp/deb-install.bash"
  download_deb_installer "${script_file}"

  # Now run the script
  sudo bash "${script_file}"
}

main "$@"
