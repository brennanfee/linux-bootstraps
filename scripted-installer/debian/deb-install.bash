#!/usr/bin/env bash
# Author: Brennan Fee
# License: MIT License
# Version: 1.7
# Date: 2023-07-01
#
# Example to run directly from URL: bash <(curl -fsSL <url here>)
#
# Short URL: https://tinyurl.com/deb-install
# Github URL: https://raw.githubusercontent.com/brennanfee/linux-bootstraps/main/scripted-installer/debian/deb-install.bash
#
# Dev branch short URL: https://tinyurl.com/dev-deb-install
# Dev branch Github URL: https://raw.githubusercontent.com/brennanfee/linux-bootstraps/develop/scripted-installer/debian/deb-install.bash
#
# This script installs Debian/Ubuntu the "Arch" way.  In order to have more
# fine-grained control it completely bypasses the Debian or Ubuntu installers
# and does all the setup here.  You must run the Debian (or Ubuntu) live
# "server" ISOs (which one shouldn't matter), truthfully it doesn't matter
# which one as you can install Ubuntu using the Debian ISO and Debian using
# the Ubuntu ISO.
#
# Bash strict mode
([[ -n ${ZSH_EVAL_CONTEXT:-} && ${ZSH_EVAL_CONTEXT:-} =~ :file$ ]] \
  || [[ -n ${BASH_VERSION:-} ]] && (return 0 2> /dev/null)) && SOURCED=true || SOURCED=false
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

## Data - These values will change from time-to-time and are placed here to have one place to
## change them without having to hunt around in the script.

# The supported target OSes to be installed
SUPPORTED_OSES=('debian' 'ubuntu')

# Should be updated whenever a new Debian stable is released
CURRENT_DEB_STABLE_CODENAME="bookworm"
CURRENT_DEB_TESTING_CODENAME="trixie"

# Should be updated with new Ubuntu releases
CURRENT_UBUNTU_LTS_CODENAME="noble"
CURRENT_UBUNTU_ROLLING_CODENAME="noble"

# Default repositories - NOTE: These should NOT end in slashes
DEFAULT_DEBIAN_REPO="https://deb.debian.org/debian"
DEFAULT_UBUNTU_REPO="http://archive.ubuntu.com/ubuntu"

# Debootstrap download filenames
DEBOOTSTRAP_PATH="pool/main/d/debootstrap"
CURRENT_DEBIAN_DEBOOTSTRAP_FILE="debootstrap_1.0.134~bpo12+1.tar.gz"
CURRENT_UBUNTU_DEBOOTSTRAP_FILE="debootstrap_1.0.134ubuntu1.tar.gz"

### End: Data

### Start: Constants & Global Variables

# Should only be on during testing.  Primarily this turns on the output of passwords and tracing
IS_DEBUG="${AUTO_IS_DEBUG:=0}"
if [[ "${IS_DEBUG}" == "1" ]]; then
  set -o xtrace # same as set -x
fi

# Paths
WORKING_DIR=$(pwd)
LOG="${WORKING_DIR}/install.log"
OUTPUT_LOG="${WORKING_DIR}/install-output.log"
[[ -f ${LOG} ]] && rm -f "${LOG}"
[[ -f ${OUTPUT_LOG} ]] && rm -f "${OUTPUT_LOG}"
INSTALL_DATE=$(date -Is)
echo "Start log: ${INSTALL_DATE}" >> "${LOG}"
echo "------------" >> "${LOG}"
echo "Start log: ${INSTALL_DATE}" | tee -a "${OUTPUT_LOG}"
echo "------------" | tee -a "${OUTPUT_LOG}"

# Auto detected flags and variables
SYS_ARCH=$(uname -m)                   # Architecture (x86_64)
DPKG_ARCH=$(dpkg --print-architecture) # Something like amd64, arm64
UEFI=0

# This is not to be confused with the OS we are going to install, this is the OS that was booted to perform the install.  This script only supports Debian and Ubuntu Live Server installers images.
INSTALLER_DISTRO=$(lsb_release -i -s | tr "[:upper:]" "[:lower:]")

# Console font size, I pre-configure the console font to enlarge it which should work better on higher resolution screens.
# The font family chosen is the Lat15-Terminus font family.  The only value changed here is the final size.
#
# Others small-ish: Lat15-Terminus14,Lat15-Terminus16,Lat15-Terminus18x10
# Others large-ish: Lat15-Terminus20x10,Lat15-Terminus22x11,Lat15-Terminus24x12,Lat15-Terminus28x14
CONSOLE_FONT_SIZE="20x10"

### End: Constants & Global Variables

### Start: Options & User Overrideable Parameters

# All options are read from environment variables allowing override of the defaults.  It is expected that the user set whatever options they want with environment variable exports before calling this script.  The overridable values all begin with "AUTO_" to indicate that they are for the "automatic" installation and to avoid potential collisions with other environment variables.
#
# Boolean values support "yes", "no", "true", "false", "0", "1", "y", "n", "t", and "f".

# The keymap to use.
AUTO_KEYMAP="${AUTO_KEYMAP:=us}"

# The system locale to use.
AUTO_LOCALE="${AUTO_LOCALE:=en_US.UTF-8}"

# The system languages to use.
AUTO_LANGUAGE="${AUTO_LANGUAGE:=en_US:en:C}"

# The time zone for the machine being created.
AUTO_TIMEZONE="${AUTO_TIMEZONE:=America/Chicago}" # Suck it east and west coast!  ;-)

# The OS to install, default is debian, alternative ubuntu.
AUTO_INSTALL_OS="${AUTO_INSTALL_OS:=debian}"

# The distro edition (sometimes called codename) to install.  For debian this is things like 'stable', 'bullesye', etc.  And for Ubuntu it is can be the codename 'jammy', 'kinetic', etc.  Ubuntu also supports the special values of 'lts' or 'rolling' for the latest LTS or rolling edition.For anything else that is "debian" based this is what should be placed into the APT sources.list.  If you do not provide a value, the default will be defined by each supported OS.  If left blank or the 'default' keyword is used this will always be the stable edition for Debian or the LTS edition for Ubuntu.
AUTO_INSTALL_EDITION="${AUTO_INSTALL_EDITION:=stable}"

# For all distro's "default" will install the default kernel for the edition requested.  However, some distributions support alternate kernels.  For those, other values may be supported.  For instance, for Debian stable you can pass "backports" to install the kernel from the backports repository (if available).  For Ubuntu LTS editions you can choose "hwe" and "hwe-edge" as alternatives.
AUTO_KERNEL_VERSION="${AUTO_KERNEL_VERSION:=default}"

# Allows the user to override the repo where the files are pulled from.  This is especially useful for situations where a local Debian or Ubuntu repository is available.
AUTO_REPO_OVERRIDE_URL="${AUTO_REPO_OVERRIDE_URL:=}"

# The default hostname of the machine being created.  If none is passed the hostname will be autogenerated.
AUTO_HOSTNAME="${AUTO_HOSTNAME:=}"

# The domain for the machine being created.
AUTO_DOMAIN="${AUTO_DOMAIN:=}"

# Whether to skip automatic partitioning.  This is a boolean value.  Note, for this to work it is expected that prior to calling this script you have partitioned AND formatted the filesystems and mounted them at /mnt ready to be bootstrapped.  This can be done manually or with a given "early" script.  Furthermore, you still need to pass in the AUTO_MAIN_DISK value that indicates where you wish Grub to be installed (and you have prepared partitions for that).  With partitioning turned off you CAN NOT use "smallest" or "largest" for AUTO_MAIN_DISK and must pass in the device path (like /dev/sda).
AUTO_SKIP_PARTITIONING="${AUTO_SKIP_PARTITIONING:=0}"

# The main disk to install the OS and Grub to.  It can be a device (like /dev/sda) or a size match like "smallest" or "largest".  When automatic partitioning, for single disk environments we create a BIOS\UEFI partition, a /boot partition, and the rest of the disk a /root partition.
AUTO_MAIN_DISK="${AUTO_MAIN_DISK:=smallest}"

# What to do with a second disk on the machine.  This setting is ignored if only one disk is found on the machine.  But in cases where two or more disks are found this indicates what should happen.  A value of "ignore", the default, will ignore the second disk and install as though the machine had only one disk (the main disk).  This is the default because it is the safest option.  Alternatively, you can pass a device (like /dev/sdb) which will manually select that as the second disk.  Lastly, as with the main disk, a size selector can be passed like "smallest" or "largest".  In the event that the main disk was selected by the same size selector, this would essentially be the next smallest or next largest disk.
#
# At no time can the second disk refer or resolve to the same disk as the main disk.  Such situations will result in an error and the script exiting.
#
# In dual disk automatic partitioning, no change is made to the main disk layout.  For the second disk, this script creates a single LVM volume on the second disk with one of two layouts (based on the AUTO_USE_DATA_DIR value).  Without the data option you get a single LVM partition of 80% for /home with 20% space free for later LVM expansion\use.  With the data directory option you get two partitions, 70% for /home, 20% for /data, and 10% empty and free for later LVM expansion\use.
AUTO_SECOND_DISK="${AUTO_SECOND_DISK:=ignore}"

# Whether the volume(s) created should be encrypted.  This is a boolean value.
AUTO_ENCRYPT_DISKS="${AUTO_ENCRYPT_DISKS:=1}"

# The password to use for the main encrypted volume.  A special value of "file", the default, can be passed which will generate a disk file in the /boot partition that will auto-decrypt on boot.  This is done so that any automated systems that expect a boot without the need of a password can still function.  You can also pass a full path (it must start with slash /, no relative paths) to a file to use, that file will be copied to the /boot partition to preserve the automatic boot nature required for automation.  Instead of a local file you can allso pass a URL to a file which should be downloaded and used, it must start with a schema, such as http:// or https://.  Lastly, you can still provide an actual passphrase which will be used.  However, this method will break any automations as typing the password will be required during boot.
#
# In all configurations, if a second disk is being used a separate file will be generated automatically as the decryption key for the second disk and stored on the root partition (in the /etc/keys directory).  The system will be configured to automatically unlock that partition after the root partition is decrypted.
#
# NOTE: This is not intended to be a secure installation without the need for the user to modify things post bootstrap.  This merely "initializes" the encryption as it is much easier to modify the encryption keys\slots later than it is to encrypt a partition which is already in use (especially root).  Therefore, it is fully expected that the user will either replace the file or otherwise manage the encryption keys after initial boot.
AUTO_DISK_PWD="${AUTO_DISK_PWD:=file}"

# Whether root should be disabled.  This is a boolean value.  The default is to NOT disable the root account.  Some feel that disabling root is a more secure installation footprint, so this setting can be used for those that wish.
AUTO_ROOT_DISABLED="${AUTO_ROOT_DISABLED:=0}"

# If root is enabled, what the root password should be.  This can be a plain text password or a crypted password.  If you do not pass a root password, we will use the same password you passed for the AUTO_USER_PWD.  If that is also blank the password will be the target installed OS in all lower case ("debian" or "ubuntu", etc.)
AUTO_ROOT_PWD="${AUTO_ROOT_PWD:=}"

# Whether to create a user.  If the root user is disabled with the AUTO_ROOT_DISABLED option, this value will be ignored as in that case a user MUST be created and so we will force the creation of this user.  However, if root is enabled you can optionally turn off the creation of a normal user.
AUTO_CREATE_USER="${AUTO_CREATE_USER:=1}"

# The username to create, if not provied defaults to a username that matches the installed OS (debian or ubuntu).
AUTO_USERNAME="${AUTO_USERNAME:=}"

# The password for the created user.  If you do not provide a password it will default to the target installed OS in all lower case ("debian" or "ubuntu", etc.). The password can be a plain text password or a crypted password.
AUTO_USER_PWD="${AUTO_USER_PWD:=}"

# A public SSH key to be set up in the created user account to allow SSH into the machine for the user.
AUTO_USER_SSH_KEY="${AUTO_USER_SSH_KEY:=}"

# Whether to create a system 'Service Account'.  This is something I do in my setups as the service account is used for
# remote access by configuration management (Ansible, Salt Stack) and sometimes to run various services or scheduled
# jobs that should not run as root but should also not run as a "regular" user.  Given this is highly specific
# to my setups it is likely you will want to leave this disabled, which is the default.  This is a boolean value.
AUTO_CREATE_SERVICE_ACCT="${AUTO_CREATE_SERVICE_ACCT:=0}"

# A public SSH key to be set up for the 'Service Account'.
AUTO_SERVICE_ACCT_SSH_KEY="${AUTO_SERVICE_ACCT_SSH_KEY:=}"

# Whether to use a /data directory or partition on the target machine.  This directory is a convention that I follow and use and is therefore disabled by default.  I use it for all non-user specific files and setups (usually of docker files, configurations, etc.).  If being used along with the AUTO_SECOND_DISK option, this value does affect the partition scheme used.  For further details on this read the information under the AUTO_SECOND_DISK option.  This is a boolean value.
AUTO_USE_DATA_DIR="${AUTO_USE_DATA_DIR:=0}"

# After installation, the install log and some other files are copied to the target machine.  This indicates (overrides) the default location.  By default, the files are copied to the /srv directory unless AUTO_USE_DATA_DIR is enabled.  With AUTO_USE_DATA_DIR turned on the files are copied to the /data directory instead of /srv.  You can override these defaults by providing a path here.  Note that your path MUST start with a full path (must start with /).
AUTO_STAMP_LOCATION="${AUTO_STAMP_LOCATION:=}"

# Install a configuration management system, helpful to have here so that on first boot it can already be installed ready to locally or remotely configure the instance.  Default is "none".  Options are: none, ansible, ansible-pip, saltstack, saltstack-repo, saltstack-bootstrap, puppet, puppet-repo
# At present I do not support Chef
AUTO_CONFIG_MANAGEMENT="${AUTO_CONFIG_MANAGEMENT:=none}"

# A list of other\extra packages to install to the target machine during the setup.
AUTO_EXTRA_PACKAGES="${AUTO_EXTRA_PACKAGES:=}"

# A list of other\extra prerequisite packages to install in the pre-installation environment.
AUTO_EXTRA_PREREQ_PACKAGES="${AUTO_EXTRA_PREREQ_PACKAGES:=}"

# A script to run BEFORE the system setup.  This must be a file path (starting with /) or a URL where the script can be download or read from, ftp:// and file:// url's should be supported.
AUTO_BEFORE_SCRIPT="${AUTO_BEFORE_SCRIPT:=}"

# A script to run after the system setup prior to reboot (if AUTO_REBOOT).  This must be a file path (starting with /) or a URL where the script can be download or read from, ftp:// and file:// url's should be supported.
AUTO_AFTER_SCRIPT="${AUTO_AFTER_SCRIPT:=}"

# A script to configure to run once on the system after initial boot.  Note, this script will run as root, before login of any user, and will ONLY RUN ONCE.  This must be a file path (starting with /) or a URL where the script can be download or read from, ftp:// and file:// url's should be supported.
AUTO_FIRST_BOOT_SCRIPT="${AUTO_FIRST_BOOT_SCRIPT:=}"

# Whether the installer should pause, display the selected and calculated values and wait for confirmation before continuing.  Off by default to preserve fully automated installations.
AUTO_CONFIRM_SETTINGS="${AUTO_CONFIRM_SETTINGS:=1}"

# Whether to automatically reboot after the script has completed.   Default is not to reboot.  Automated environments such as Packer should turn this on.
AUTO_REBOOT="${AUTO_REBOOT:=0}"

### END: Options & User Overrideable Parameters

### START: Params created during verification

SELECTED_INSTALL_EDITION=""

SELECTED_MAIN_DISK=""
SELECTED_SECOND_DISK=""
ENCRYPTION_FILE=""
SECONDARY_FILE=""

SELECTED_STAMP_LOCATION=""
SELECTED_REPO_URL=""

SELECTED_CHARMAP="UTF-8"

### END: Params created during verification

### START: Log Functions

write_log() {
  echo "LOG: ${1}" >> "${LOG}"
  if [[ "${IS_DEBUG}" == "1" ]]; then
    echo "LOG: ${1}" | tee -a "${OUTPUT_LOG}"
  fi
}

write_log_password() {
  if [[ "${IS_DEBUG}" == "1" ]]; then
    write_log "${1}"
  else
    local val
    val=${1//:*/: ******}
    write_log "${val}"
  fi
}

write_debug() {
  write_log "DEBUG: ${1}"
}

write_log_blank() {
  write_log ""
}

write_log_spacer() {
  write_log "------"
}

log_values() {
  write_log_spacer
  write_log "Post Validation Values"
  write_log_blank

  local boot_options
  boot_options=$(cat /proc/cmdline)

  write_log "SCRIPT VERSION: ${SCRIPT_VERSION}"
  write_log "SCRIPT DATE: ${SCRIPT_DATE}"
  write_log "KERNEL BOOT OPTIONS: '${boot_options}'"
  write_log_blank

  write_log "INSTALL_DATE: ${INSTALL_DATE}"
  write_log "INSTALLER_DISTRO: ${INSTALLER_DISTRO}"
  write_log "SYS_ARCH: ${SYS_ARCH}"
  write_log "DPKG_ARCH: ${DPKG_ARCH}"
  write_log "UEFI: ${UEFI}"
  write_log "IS_DEBUG: ${IS_DEBUG}"
  write_log_blank

  write_log "AUTO_KEYMAP: '${AUTO_KEYMAP}'"
  write_log "AUTO_LOCALE: '${AUTO_LOCALE}'"
  write_log "AUTO_LANGUAGE: '${AUTO_LANGUAGE}'"
  write_log "AUTO_TIMEZONE: '${AUTO_TIMEZONE}'"
  write_log_blank

  write_log "AUTO_INSTALL_OS: '${AUTO_INSTALL_OS}'"
  write_log "AUTO_INSTALL_EDITION: '${AUTO_INSTALL_EDITION}'"
  write_log "AUTO_KERNEL_VERSION: '${AUTO_KERNEL_VERSION}'"
  write_log "AUTO_REPO_OVERRIDE_URL: '${AUTO_REPO_OVERRIDE_URL}'"
  write_log_blank

  write_log "AUTO_HOSTNAME: '${AUTO_HOSTNAME}'"
  write_log "AUTO_DOMAIN: '${AUTO_DOMAIN}'"
  write_log_blank

  write_log "AUTO_SKIP_PARTITIONING: '${AUTO_SKIP_PARTITIONING}'"
  write_log "AUTO_MAIN_DISK: '${AUTO_MAIN_DISK}'"
  write_log "AUTO_SECOND_DISK: '${AUTO_SECOND_DISK}'"
  write_log "AUTO_ENCRYPT_DISKS: '${AUTO_ENCRYPT_DISKS}'"
  case "${AUTO_DISK_PWD}" in
    file)
      write_log "AUTO_DISK_PWD: file"
      ;;
    tpm) # Future
      write_log "AUTO_DISK_PWD: tpm"
      ;;
    /*)
      write_log "AUTO_DISK_PWD: Provided local file '${AUTO_DISK_PWD}'"
      ;;
    http://* | https://* | ftp://* | ftps://* | sftp://* | file://*)
      write_log "AUTO_DISK_PWD: Provided remote file '${AUTO_DISK_PWD}'"
      ;;
    *)
      write_log_password "AUTO_DISK_PWD (Password): '${AUTO_DISK_PWD}'"
      ;;
  esac
  write_log_blank

  write_log "AUTO_ROOT_DISABLED: '${AUTO_ROOT_DISABLED}'"
  write_log_password "AUTO_ROOT_PWD: '${AUTO_ROOT_PWD}'"
  write_log "AUTO_CREATE_USER: '${AUTO_CREATE_USER}'"
  write_log "AUTO_USERNAME: '${AUTO_USERNAME}'"
  write_log_password "AUTO_USER_PWD: '${AUTO_USER_PWD}'"
  write_log "AUTO_USER_SSH_KEY: '${AUTO_USER_SSH_KEY}'"
  write_log "AUTO_CREATE_SERVICE_ACCT: '${AUTO_CREATE_SERVICE_ACCT}'"
  write_log "AUTO_SERVICE_ACCT_SSH_KEY: '${AUTO_SERVICE_ACCT_SSH_KEY}'"
  write_log_blank

  write_log "AUTO_USE_DATA_DIR: '${AUTO_USE_DATA_DIR}'"
  write_log "AUTO_STAMP_LOCATION: '${AUTO_STAMP_LOCATION}'"
  write_log "AUTO_CONFIG_MANAGEMENT: '${AUTO_CONFIG_MANAGEMENT}'"
  write_log "AUTO_EXTRA_PACKAGES: '${AUTO_EXTRA_PACKAGES}'"
  write_log "AUTO_EXTRA_PREREQ_PACKAGES: '${AUTO_EXTRA_PREREQ_PACKAGES}'"
  write_log_blank

  write_log "AUTO_BEFORE_SCRIPT: '${AUTO_BEFORE_SCRIPT}'"
  write_log "AUTO_AFTER_SCRIPT: '${AUTO_AFTER_SCRIPT}'"
  write_log "AUTO_FIRST_BOOT_SCRIPT: '${AUTO_FIRST_BOOT_SCRIPT}'"
  write_log_blank

  write_log "AUTO_CONFIRM_SETTINGS: '${AUTO_CONFIRM_SETTINGS}'"
  write_log "AUTO_REBOOT: '${AUTO_REBOOT}'"
  write_log_blank

  write_log "--- Calculated values ---"
  write_log "SELECTED_CHARMAP: '${SELECTED_CHARMAP}'"
  write_log "SELECTED_INSTALL_EDITION: '${SELECTED_INSTALL_EDITION}'"
  write_log "MAIN_DISK_METHOD: '${MAIN_DISK_METHOD}'"
  write_log "SELECTED_MAIN_DISK: '${SELECTED_MAIN_DISK}'"
  write_log "SECOND_DISK_METHOD: '${SECOND_DISK_METHOD}'"
  write_log "SELECTED_SECOND_DISK: '${SELECTED_SECOND_DISK}'"
  write_log "ENCRYPTION_FILE: '${ENCRYPTION_FILE}'"
  write_log "SECONDARY_FILE: '${SECONDARY_FILE}'"
  write_log "SELECTED_REPO_URL: '${SELECTED_REPO_URL}'"
  write_log "SELECTED_STAMP_LOCATION: '${SELECTED_STAMP_LOCATION}'"
  write_log_blank

  write_log_spacer
}

confirm_with_user() {
  if [[ "${AUTO_CONFIRM_SETTINGS}" == "1" || "${IS_DEBUG}" == "1" ]]; then
    print_title
    print_summary_header "Install Summary (Part 1)" "Below is a summary of your selections and any detected system information.  If anything is wrong cancel out now with Ctrl-C.  Otherwise press any key to view the rest of the configurations."
    print_line
    if [[ "${UEFI}" == "1" ]]; then
      print_status "The architecture is ${SYS_ARCH}, dpkg ${DPKG_ARCH}, and UEFI has been found."
    else
      print_status "The architecture is ${SYS_ARCH}, dpkg ${DPKG_ARCH}, and a BIOS has been found."
    fi
    print_status "It appears you are installing from a '${INSTALLER_DISTRO}' installer medium."
    blank_line

    print_status "The selected keymap is '${AUTO_KEYMAP}', locale is '${AUTO_LOCALE}', language is '${AUTO_LANGUAGE}', and the selected timezone is '${AUTO_TIMEZONE}'."

    print_status "The distribution to install is '${AUTO_INSTALL_OS}', '${SELECTED_INSTALL_EDITION}' edition."

    print_status "The kernel version to install, if available, is '${AUTO_KERNEL_VERSION}'."

    print_status "The repository URL to use is '${SELECTED_REPO_URL}'."

    local domain_info
    if [[ "${AUTO_DOMAIN}" != "" ]]; then
      domain_info="The domain selected is '${AUTO_DOMAIN}'."
    else
      domain_info="No domain was provided."
    fi
    if [[ "${AUTO_HOSTNAME}" == "" ]]; then
      print_status "The hostname will be auto-generated. ${domain_info}"
    else
      print_status "The hostname selected is '${AUTO_HOSTNAME}'. ${domain_info}"
    fi
    blank_line

    if [[ "${AUTO_SKIP_PARTITIONING}" == "1" ]]; then
      print_status "Automatic disk partitioning has been DISABLED.  You should have already manually setup the target /mnt directory, performing any needed disk partitioning and mounting.  This can be done either manually before calling this script or in a provided 'before' script."
    else
      print_status "The main disk option was '${AUTO_MAIN_DISK}', the selection method was '${MAIN_DISK_METHOD}'."
      print_status "The selected main disk is '${SELECTED_MAIN_DISK}'."

      print_status "The secondary disk option was '${AUTO_SECOND_DISK}', the selection method was '${SECOND_DISK_METHOD}'."
      print_status "The selected secondary disk is '${SELECTED_SECOND_DISK}'."

      local encryption_method
      case "${AUTO_DISK_PWD}" in
        file)
          encryption_method="file"
          ;;
        tpm) # Future
          encryption_method="tpm"
          ;;
        /*)
          encryption_method="provided local file"
          ;;
        http://* | https://* | ftp://* | ftps://* | sftp://* | file://*)
          encryption_method="provided remote file"
          ;;
        *)
          encryption_method="password"
          ;;
      esac

      if [[ "${AUTO_ENCRYPT_DISKS}" == "1" ]]; then
        print_status "The disks will be encrypted.  Encryption method is: '${encryption_method}'"
      else
        print_status "The disks will NOT be encrypted."
      fi
    fi
    blank_line

    if [[ "${AUTO_ROOT_DISABLED}" == "1" ]]; then
      print_status "The root account will be disabled."
    else
      print_status "The root account will be activated."
    fi

    if [[ "${AUTO_CREATE_USER}" == "1" ]]; then
      if [[ "${AUTO_USERNAME}" == "" ]]; then
        print_status "A default user '${AUTO_INSTALL_OS}' will be created and granted sudo permissions."
      else
        print_status "User '${AUTO_USERNAME}' will be created and granted sudo permissions."
      fi
      if [[ "${AUTO_USER_SSH_KEY}" != "" ]]; then
        print_status "A public SSH key will be set up in the user account."
      else
        print_status "No public SSH key will be set up in the user account."
      fi
    else
      print_status "User creation was disabled."
    fi
    blank_line

    if [[ "${AUTO_CREATE_SERVICE_ACCT}" == "1" ]]; then
      print_status "The 'Service Account' will be created and configured."
      blank_line
    fi

    pause_output

    #### Second page

    print_title
    print_summary_header "Install Summary (Part 2)" "Below are more of your selections and any detected system information.  If anything is wrong cancel out now with Ctrl-C.  Otherwise press any key to continue installation."
    print_line

    if [[ "${AUTO_USE_DATA_DIR}" == "1" ]]; then
      print_status "The data directory and related configurations will be deployed."
    else
      print_status "The data directory and related configurations are being SKIPPED."
    fi

    print_status "The stamp location (copy location for install log files) will be '${SELECTED_STAMP_LOCATION}'."
    blank_line

    if [[ "${AUTO_CONFIG_MANAGEMENT}" == "none" ]]; then
      print_status "No configuration management software will be pre-installed."
    else
      print_status "Configuration management software will be pre-installed: '${AUTO_CONFIG_MANAGEMENT}'."
    fi

    if [[ "${AUTO_EXTRA_PACKAGES}" == "" ]]; then
      print_status "No extra packages have been requested to be pre-installed."
    else
      print_status "Extra packages have been selected to be pre-installed: '${AUTO_EXTRA_PACKAGES}'."
    fi
    if [[ "${AUTO_EXTRA_PREREQ_PACKAGES}" == "" ]]; then
      print_status "No extra prerequisite pre-installation packages have been requested to be installed."
    else
      print_status "Extra prerequisite pre-installation packages have been selected to be installed: '${AUTO_EXTRA_PREREQ_PACKAGES}'."
    fi
    blank_line

    if [[ "${AUTO_BEFORE_SCRIPT}" == "" ]]; then
      print_status "No 'before' script has been provided."
    else
      print_status "'Before' script selected is '${AUTO_BEFORE_SCRIPT}'."
    fi

    if [[ "${AUTO_AFTER_SCRIPT}" == "" ]]; then
      print_status "No 'after' script has been provided."
    else
      print_status "'After' script selected is '${AUTO_AFTER_SCRIPT}'."
    fi

    if [[ "${AUTO_FIRST_BOOT_SCRIPT}" == "" ]]; then
      print_status "No 'first boot' script has been provided."
    else
      print_status "'First boot' script selected is '${AUTO_FIRST_BOOT_SCRIPT}'."
    fi
    blank_line

    if [[ "${AUTO_REBOOT}" == "1" ]]; then
      print_status "The system will automatically boot after installation."
    else
      print_status "The system will NOT automatically boot after installation.  You will have the opportunity to manually continue configurations.  The taget chroot location is /mnt.  BE SURE TO UNMOUNT IT BEFORE REBOOTING!"
    fi
    blank_line

    pause_output
  else
    write_log "Skipping settings confirmation.  Option not selected."
  fi
}

### START: Log Functions

### START: Print Functions

# Text modifiers
RESET="$(tput sgr0)"
BOLD="$(tput bold)"

print_title() {
  clear
  print_line
  local text="Deb-Install Automated Bootstrapper - Author: ${SCRIPT_AUTHOR} - License: ${SCRIPT_LICENSE}"
  echo -e "# ${BOLD}${text}${RESET}"
  write_log "TITLE: ${text}"
  print_line
  blank_line
}

print_summary_header() {
  local T_COLS
  T_COLS=$(tput cols)
  T_COLS=$((T_COLS - 10))
  echo -e "${BOLD}$1${RESET}\n\n${BOLD}$2${RESET}\n" | fold -sw "${T_COLS}" | sed 's/^/\t/'
  write_log "SUMMARY HEADER : ${1}"
  write_log "SUMMARY INFO : ${2}"
}

print_line() {
  local T_COLS
  T_COLS=$(tput cols)
  printf "%${T_COLS}s\n" | tr ' ' '-'
  write_log_spacer
}

blank_line() {
  echo ""
  write_log_blank
}

print_status() {
  local T_COLS
  T_COLS=$(tput cols)
  T_COLS=$((T_COLS - 1))
  echo -e "$1${RESET}" | fold -sw "${T_COLS}"
  write_log "STATUS: ${1}"
}

print_info() {
  local T_COLS
  T_COLS=$(tput cols)
  T_COLS=$((T_COLS - 1))
  echo -e "${BOLD}$1${RESET}" | fold -sw "${T_COLS}"
  write_log "INFO: ${1}"
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

pause_output() {
  print_line
  read -re -sn 1 -p "Press enter to continue..."
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

### START: Print Functions

### START: Helper Functions

setup_installer_environment() {
  print_info "Setting up installer environment..."
  ### Locale
  write_log "Setting locale"
  # always enable en_US.UTF-8
  sed -i -E '/en_US.UTF-8\s/ c\en_US.UTF-8 UTF-8' /etc/locale.gen
  # now enable their locale
  sed -i -E "s/^#\s${AUTO_LOCALE}\s(.*)$/${AUTO_LOCALE} \1/" /etc/locale.gen
  dpkg-reconfigure --frontend=noninteractive locales

  # Read the charmap...
  write_log "Reading Charmap"
  SELECTED_CHARMAP=$(grep "${AUTO_LOCALE}\s" /etc/locale.gen | cut -d' ' -f 2)

  write_log "Writing locale"
  update-locale --reset LANG="${AUTO_LOCALE}" LANGUAGE="${AUTO_LANGUAGE}"

  export LANG="${AUTO_LOCALE}"
  export LANGUAGE="${AUTO_LANGUAGE}"

  ### Keymap
  write_log "Setting keymap"
  loadkeys "${AUTO_KEYMAP}"

  ### Resolution
  write_log "Setting resolution"
  local detected_virt
  detected_virt=$(systemd-detect-virt || true)
  if [[ "${detected_virt}" == "oracle" ]]; then
    fbset -xres 1280 -yres 720 -depth 32 -match
  fi

  ### Console Font
  write_log "Setting console font"
  setfont "Lat15-Terminus${CONSOLE_FONT_SIZE}"
}

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

chroot_install() {
  write_log "Installing to target: '$*'"
  DEBIAN_FRONTEND=noninteractive arch-chroot /mnt apt-get -y -q install "$@"
}

chroot_run_updates() {
  write_log "Running apt updates"
  DEBIAN_FRONTEND=noninteractive arch-chroot /mnt apt-get -y -q update
  DEBIAN_FRONTEND=noninteractive arch-chroot /mnt apt-get -y -q full-upgrade
  DEBIAN_FRONTEND=noninteractive arch-chroot /mnt apt-get -y -q autoremove
}

local_install() {
  write_log "Installing locally: '$*'"
  DEBIAN_FRONTEND=noninteractive apt-get -y -q install "$@"
}

package_exists() {
  local apt
  apt=$(arch-chroot /mnt apt-cache -q=2 show "$1" 2>&1 | head -n 1 || true)
  if [[ "${apt}" == Package* ]]; then
    return 0
  else
    return 1
  fi
}

### END: Helper Functions

### START: System Verification Functions

check_root() {
  print_info "Checking root permissions..."

  local user_id
  user_id=$(id -u)
  if [[ "${user_id}" != "0" ]]; then
    error_msg "ERROR! You must execute the script as the 'root' user."
  fi
}

check_linux_distro() {
  print_info "Checking installer distribution..."
  write_log "Installer distro detected: ${INSTALLER_DISTRO}"

  if [[ "${INSTALLER_DISTRO}" != "debian" && "${INSTALLER_DISTRO}" != "ubuntu" ]]; then
    error_msg "ERROR! You must execute the script on a Debian or Ubuntu Server Live Image."
  fi
}

detect_if_eufi() {
  print_info "Detecting UEFI..."

  local vendor
  vendor=$(cat /sys/class/dmi/id/sys_vendor)
  if [[ "${vendor}" == 'Apple Inc.' ]] || [[ "${vendor}" == 'Apple Computer, Inc.' ]]; then
    modprobe -r -q efivars || true # if MAC
  else
    modprobe -q efivarfs || true # all others
  fi

  if [[ -d "/sys/firmware/efi/" ]]; then
    ## Mount efivarfs if it is not already mounted
    if [[ ! -d "/sys/firmware/efi/efivars" ]]; then
      mount -t efivarfs efivarfs /sys/firmware/efi/efivars
    fi
    UEFI=1
  else
    UEFI=0
  fi
}

check_network_connection() {
  print_info "Checking network connectivity..."

  local attempts=0
  local sleepLength=2

  while true; do
    attempts=$((attempts + 1))
    if [[ ${attempts} -gt 5 ]]; then
      error_msg "No connection found after 5 attempts."
    fi

    if [[ "$(hostname -I)" != "" ]]; then
      # Check localhost first (if network stack is up at all)
      if ping -q -w 3 -c 2 localhost &> /dev/null; then
        # Test the internet
        if wget -q --spider https://www.google.com; then
          print_info "Connection found."
          break
        else
          write_debug "wget failed, retrying..."
          sleep "${sleepLength}"
        fi
      else
        write_debug "ping failed, retrying..."
        sleep "${sleepLength}"
      fi
    else
      write_debug "hostname check failed, retrying..."
      sleep "${sleepLength}"
    fi
  done
}

### END: System Verification Functions

### START: Preparation Functions

install_prereqs() {
  print_info "Installing prerequisites"
  DEBIAN_FRONTEND=noninteractive apt-get -y -q update || true
  DEBIAN_FRONTEND=noninteractive apt-get -y -q full-upgrade || true
  DEBIAN_FRONTEND=noninteractive apt-get -y -q autoremove || true

  # Things all systems need (reminder these are being installed to the installation environment, not the target machine)
  print_status "    Installing common prerequisites"
  local_install vim arch-install-scripts parted bc cryptsetup lvm2 xfsprogs laptop-detect ntp console-data locales fbset dosfstools

  if [[ "${AUTO_EXTRA_PREREQ_PACKAGES}" != "" ]]; then
    print_status "    Installing user requested prerequisites"
    local_install "${AUTO_EXTRA_PREREQ_PACKAGES}"
  fi
}

get_debootstrap() {
  print_info "Getting debootstrap"

  local debootstrap_file
  case "${AUTO_INSTALL_OS}" in
    debian)
      debootstrap_file="${CURRENT_DEBIAN_DEBOOTSTRAP_FILE}"
      ;;
    ubuntu)
      debootstrap_file="${CURRENT_UBUNTU_DEBOOTSTRAP_FILE}"
      ;;
    *)
      error_msg "ERROR! OS to install not supported: '${AUTO_INSTALL_OS}'"
      ;;
  esac

  local debootstrap_url="${SELECTED_REPO_URL}/${DEBOOTSTRAP_PATH}/${debootstrap_file}"

  mkdir -p "/debootstrap"
  wget -O "/home/user/debootstrap.tar.gz" "${debootstrap_url}"
  tar zxvf "/home/user/debootstrap.tar.gz" --directory="/debootstrap" --strip-components=1
  chmod +x /debootstrap/debootstrap

  # Protect against Ubuntu team being lazy
  if [[ ! -f "/debootstrap/scripts/${SELECTED_INSTALL_EDITION}" ]]; then
    local destFile="debian-common"
    if [[ "${AUTO_INSTALL_OS}" == "ubuntu" ]]; then
      destFile="gutsy"
    fi

    ln -s "/debootstrap/scripts/${destFile}" "/debootstrap/scripts/${SELECTED_INSTALL_EDITION}"
  fi
}

setup_clock() {
  print_info "Setting up system clock"

  hwclock --systohc --utc --update-drift
  timedatectl set-local-rtc 0
  timedatectl set-timezone "${AUTO_TIMEZONE}"

  # Set the time with ntp once
  ntpd -gq || true
}

### END: Preparation Functions

### START: Parameter Verification Functions

normalize_variable_string() {
  local tmp
  tmp=$(echo "${!1}" | tr "[:upper:]" "[:lower:]")
  printf -v "$1" '%s' "${tmp}"
}

normalize_variable_boolean() {
  local input
  local output
  input=${!1}
  if [[ "${input}" == "yes" || "${input}" == "true" || "${input}" == "y" || "${input}" == "t" || "${input}" == "1" ]]; then
    output="1"
  elif [[ "${input}" == "no" || "${input}" == "false" || "${input}" == "n" || "${input}" == "f" || "${input}" == "0" ]]; then
    output="0"
  else
    echo "ERROR!!! Invalid option."
    exit 1
  fi

  printf -v "$1" '%s' "${output}"
}

normalize_parameters() {
  print_info "Normalizing inputs"

  normalize_variable_string "AUTO_KEYMAP"
  normalize_variable_string "AUTO_INSTALL_OS"
  normalize_variable_string "AUTO_INSTALL_EDITION"
  normalize_variable_string "AUTO_KERNEL_VERSION"
  normalize_variable_string "AUTO_REPO_OVERRIDE_URL"
  normalize_variable_string "AUTO_HOSTNAME"
  normalize_variable_string "AUTO_DOMAIN"
  normalize_variable_string "AUTO_MAIN_DISK"
  normalize_variable_string "AUTO_SECOND_DISK"
  normalize_variable_string "AUTO_USERNAME"
  normalize_variable_string "AUTO_CONFIG_MANAGEMENT"

  normalize_variable_boolean "AUTO_SKIP_PARTITIONING"
  normalize_variable_boolean "AUTO_USE_DATA_DIR"
  normalize_variable_boolean "AUTO_ENCRYPT_DISKS"
  normalize_variable_boolean "AUTO_ROOT_DISABLED"
  normalize_variable_boolean "AUTO_CREATE_USER"
  normalize_variable_boolean "AUTO_CREATE_SERVICE_ACCT"
  normalize_variable_boolean "AUTO_CONFIRM_SETTINGS"
  normalize_variable_boolean "AUTO_REBOOT"
}

log_and_confirm() {
  log_values
  confirm_with_user
}

verify_install_os() {
  print_info "Verifying Install OS"
  get_exit_code contains_element "${AUTO_INSTALL_OS}" "${SUPPORTED_OSES[@]}"
  if [[ ! "${EXIT_CODE}" == "0" ]]; then
    error_msg "Invalid OS to install: '${AUTO_INSTALL_OS}'"
  fi
}

verify_install_edition() {
  print_info "Verifying Install OS"

  SELECTED_INSTALL_EDITION="${AUTO_INSTALL_EDITION}"
  if [[ "${AUTO_INSTALL_OS}" == "ubuntu" ]]; then
    if [[ "${SELECTED_INSTALL_EDITION}" == "lts" ]]; then
      SELECTED_INSTALL_EDITION="${CURRENT_UBUNTU_LTS_CODENAME}"
    elif [[ "${SELECTED_INSTALL_EDITION}" == "rolling" ]]; then
      SELECTED_INSTALL_EDITION="${CURRENT_UBUNTU_ROLLING_CODENAME}"
    elif [[ "${SELECTED_INSTALL_EDITION}" == "stable" ]]; then
      # Handles the edge case where they said ubuntu but kept the default
      # 'stable' for edition
      SELECTED_INSTALL_EDITION="${CURRENT_UBUNTU_LTS_CODENAME}"
    fi
  fi
}

verify_kernel_version() {
  print_info "Verifying Kernel Version"
  local options
  case "${AUTO_INSTALL_OS}" in
    debian)
      options=('default' 'backport' 'backports')
      get_exit_code contains_element "${AUTO_KERNEL_VERSION}" "${options[@]}"
      if [[ ! "${EXIT_CODE}" == "0" ]]; then
        error_msg "Invalid Debian kernel version to install: '${AUTO_KERNEL_VERSION}'"
      fi
      ;;

    ubuntu)
      options=('default' 'hwe' 'hwe-edge' 'hwe_edge' 'backport' 'backports')
      get_exit_code contains_element "${AUTO_KERNEL_VERSION}" "${options[@]}"
      if [[ ! "${EXIT_CODE}" == "0" ]]; then
        error_msg "Invalid Ubuntu kernel version to install: '${AUTO_KERNEL_VERSION}'"
      fi
      # Normalize the two edge options
      if [[ "${AUTO_KERNEL_VERSION}" == "hwe_edge" ]]; then
        AUTO_KERNEL_VERSION="hwe-edge"
      fi
      # Normalize the debian backport(s)
      if [[ "${AUTO_KERNEL_VERSION}" == "backport" || "${AUTO_KERNEL_VERSION}" == "backports" ]]; then
        AUTO_KERNEL_VERSION="hwe-edge"
      fi
      ;;

    *)
      error_msg "ERROR! OS to install not supported: '${AUTO_INSTALL_OS}'"
      ;;
  esac
}

verify_timezone() {
  print_info "Verifying Timezone"
  local tz_exists
  tz_exists=$(timedatectl list-timezones | grep -c "^${AUTO_TIMEZONE}$")
  if [[ ${tz_exists} -ne 1 ]]; then
    error_msg "ERROR! Invalid time zone selected: '${AUTO_TIMEZONE}'"
  fi
}

verify_user_configuration() {
  print_info "Verifying User Configuration"
  # If the root user and service account user is disabled, we need to force the normal user to be created
  if [[ "${AUTO_ROOT_DISABLED}" == "1" && "${AUTO_CREATE_SERVICE_ACCT}" == "0" ]]; then
    AUTO_CREATE_USER=1
  fi

  if [[ "${AUTO_USERNAME}" == "root" ]]; then
    error_msg "The user to create cannot be named 'root'."
  fi

  if [[ "${AUTO_USERNAME}" == "svcacct" ]]; then
    error_msg "The user to create cannot be named 'svcacct'."
  fi
}

verify_disk_password() {
  print_info "Verifying Disk Password"
  if [[ "${AUTO_DISK_PWD}" == "" ]]; then
    AUTO_DISK_PWD="file"
  fi
}

verify_mount_point() {
  print_info "Verifying mount point"
  # All we need is that /mnt is a mountpoint
  if [[ $(mount | grep -c ' /mnt ') -eq 0 ]]; then
    error_msg "Bypass of automatic partitioning has been selected but the mount point (/mnt) for the target machine is not mounted.  To skip automatic partitioning, you first must perform the partitioning manually or by script and ensure that the intended target / (root) and all sub-paths desired are mounted at /mnt."
  fi
}

verify_disk_input() {
  local input
  input=${!1}
  shift
  if echo "${input}" | grep -q '^/dev/'; then
    if ! lsblk -ndpr --output NAME,RO,HOTPLUG,MOUNTPOINT | awk '$2 == "0" && $3 == "0" && $4 == "" {print $1}' | grep -q "${input}"; then
      echo "Invalid device selection option: '${input}'"
    fi
  else
    get_exit_code contains_element "${input}" "$@"
    if [[ ! "${EXIT_CODE}" == "0" ]]; then
      echo "Invalid disk selection option: '${input}'"
      exit 1
    fi
  fi
}

verify_disk_inputs() {
  print_info "Verifying disk inputs"
  if [[ "${AUTO_SKIP_PARTITIONING}" == "1" ]]; then
    verify_mount_point

    if ! echo "${AUTO_MAIN_DISK}" | grep -q '^/dev/'; then
      error_msg "When skipping automatic partitioning, a device path (like /dev/sda) MUST be passed into AUTO_MAIN_DISK to indicate where the GRUB bootloader should be installed, value received: '${AUTO_MAIN_DISK}'"
    fi
  else
    verify_disk_input "AUTO_MAIN_DISK" 'smallest' 'largest'
    verify_disk_input "AUTO_SECOND_DISK" 'smallest' 'largest' 'ignore'
  fi
}

verify_config_management() {
  print_info "Verifying config management"

  options=('none' 'ansible' 'ansible-pip' 'saltstack' 'saltstack-repo' 'saltstack-bootstrap' 'puppet' 'puppet-repo')
  get_exit_code contains_element "${AUTO_CONFIG_MANAGEMENT}" "${options[@]}"
  if [[ ! "${EXIT_CODE}" == "0" ]]; then
    error_msg "Invalid Configuration management option: '${AUTO_CONFIG_MANAGEMENT}'"
  fi
}

parse_main_disk() {
  print_info "Reading Main Disk Selection"

  if echo "${AUTO_MAIN_DISK}" | grep -q '^/dev/'; then
    # We have already verified the disk prior, so no need to do anything else
    MAIN_DISK_METHOD="direct"
    SELECTED_MAIN_DISK="${AUTO_MAIN_DISK}"
  else
    if [[ "${AUTO_SKIP_PARTITIONING}" == "1" ]]; then
      # This should never happen, but here just in case
      error_msg "An error in configuration regarding partition has been found. Exiting."
    fi

    case "${AUTO_MAIN_DISK}" in
      smallest)
        MAIN_DISK_METHOD="smallest"
        SELECTED_MAIN_DISK=$(lsblk -ndpr --output NAME,RO,HOTPLUG,MOUNTPOINT --sort SIZE | awk '$2 == "0" && $3 == "0" && $4 == "" {print $1}' | head -n 1)
        ;;

      largest)
        MAIN_DISK_METHOD="largest"
        SELECTED_MAIN_DISK=$(lsblk -ndpr --output NAME,RO,HOTPLUG,MOUNTPOINT --sort SIZE | awk '$2 == "0" && $3 == "0" && $4 == "" {print $1}' | tail -n 1)
        ;;

      *)
        # Should never happen as we have already verified thie value
        error_msg "ERROR! Invalid main disk selection: '${AUTO_MAIN_DISK}'"
        ;;
    esac
  fi

  # One more validation if it is a valid disk/device locator
  if [[ ! -b "${SELECTED_MAIN_DISK}" ]]; then
    error_msg "ERROR! Invalid main disk selected '${SELECTED_MAIN_DISK}'."
  fi

  write_log "Main disk selection method: '${MAIN_DISK_METHOD}'"
  write_log "Main disk selected: '${SELECTED_MAIN_DISK}'"
}

parse_second_disk() {
  print_info "Reading Second Disk Selection"

  print_status "    Collecting disks..."
  local devices
  devices=$(lsblk -ndpr --output NAME,RO,HOTPLUG,MOUNTPOINT | awk '$2 == "0" && $3 == "0" && $4 == "" {print $1}' | grep -v "${SELECTED_MAIN_DISK}" || true)
  write_log "Secondary devices: ${devices}"

  local devices_list=()
  while read -r line; do
    if [[ "${line}" != "" ]]; then
      devices_list+=("${line}")
    fi
  done <<< "${devices[@]}"
  write_log "Secondary devices array: ${devices_list[*]}"
  write_log "Secondary devices array count: ${#devices_list[@]}"

  write_log "checking for second disk"
  if [[ "${AUTO_SKIP_PARTITIONING}" == "1" || "${#devices_list[@]}" == "0" ]]; then
    write_log "Forcing ingore for second disk due to only 1 disk in system"
    # There is only 1 disk in the system or the user has chosen to skip partitioning, so regardless of what they asked for on second disk it should be ignored
    SECOND_DISK_METHOD="forced"
    SELECTED_SECOND_DISK="ignore"

    write_log "Second disk selection method: '${SECOND_DISK_METHOD}'"
    write_log "Second disk selected: ${SELECTED_SECOND_DISK}"

    return
  fi

  write_log "Checking second disk"
  write_log "AUTO_SECOND_DISK=${AUTO_SECOND_DISK}"
  case "${AUTO_SECOND_DISK}" in
    /dev/*)
      # We have already verified the disk prior, so need need to do anything else
      SECOND_DISK_METHOD="direct"
      SELECTED_SECOND_DISK="${AUTO_SECOND_DISK}"
      ;;
    ignore)
      SECOND_DISK_METHOD="ignore"
      SELECTED_SECOND_DISK="ignore"
      ;;

    smallest)
      SECOND_DISK_METHOD="smallest"
      SELECTED_SECOND_DISK=$(lsblk -ndpr --output NAME,RO,HOTPLUG,MOUNTPOINT --sort SIZE | awk '$2 == "0" && $3 == "0" && $4 == "" {print $1}' | grep -v "${SELECTED_MAIN_DISK}" | head -n 1 || true)
      ;;

    largest)
      SECOND_DISK_METHOD="largest"
      SELECTED_SECOND_DISK=$(lsblk -ndpr --output NAME,RO,HOTPLUG,MOUNTPOINT --sort SIZE | awk '$2 == "0" && $3 == "0" && $4 == "" {print $1}' | grep -v "${SELECTED_MAIN_DISK}" | tail -n 1 || true)
      ;;

    *)
      # Should never happen as we have already verified thie value
      error_msg "ERROR! Invalid second disk selection: '${AUTO_SECOND_DISK}'"
      ;;
  esac

  # One more validation if it is a valid disk/device locator
  if [[ "${SELECTED_SECOND_DISK}" != "ignore" && ! -b "${SELECTED_SECOND_DISK}" ]]; then
    error_msg "ERROR! Invalid second disk selected '${SELECTED_SECOND_DISK}'."
  fi

  # Verify it is not the same as the main disk
  if [[ "${SELECTED_SECOND_DISK}" == "${SELECTED_MAIN_DISK}" ]]; then
    error_msg "ERROR! Main disk and second disk can not be the same disk."
  fi

  write_log "Second disk selection method: '${SECOND_DISK_METHOD}'"
  write_log "Second disk selected: '${SELECTED_SECOND_DISK}'"
}

parse_repo_url() {
  print_info "Determining repo url"

  case "${AUTO_INSTALL_OS}" in
    debian)
      SELECTED_REPO_URL="${DEFAULT_DEBIAN_REPO}"
      ;;
    ubuntu)
      SELECTED_REPO_URL="${DEFAULT_UBUNTU_REPO}"
      ;;
    *)
      error_msg "ERROR! OS to install not supported: '${AUTO_INSTALL_OS}'"
      ;;
  esac

  if [[ "${AUTO_REPO_OVERRIDE_URL}" != "" ]]; then
    SELECTED_REPO_URL="${AUTO_REPO_OVERRIDE_URL}"
  fi
}

parse_stamp_path() {
  print_info "Determining stamp path"

  SELECTED_STAMP_LOCATION="${AUTO_STAMP_LOCATION}"
  if [[ "${SELECTED_STAMP_LOCATION}" == "" ]]; then
    SELECTED_STAMP_LOCATION="/srv"

    if [[ "${AUTO_USE_DATA_DIR}" == "1" ]]; then
      SELECTED_STAMP_LOCATION="/data"
    fi
  fi
}

### END: Parameter Verification  Functions

### START: Disk And Partition Functions

unmount_partitions() {
  print_info "Unmounting partitions"
  swapoff -a
  umount -R "/mnt" || true
}

wipe_disks() {
  print_info "Wiping disks"

  print_info "    Wiping main disk partitions"
  wipefs --all --force "${SELECTED_MAIN_DISK}*" 2> /dev/null || true
  wipefs --all --force "${SELECTED_MAIN_DISK}" || true

  local sector_count
  sector_count=$(blockdev --getsz "${SELECTED_MAIN_DISK}")
  sector_count=$((sector_count - 100))

  dd if=/dev/zero of="${SELECTED_MAIN_DISK}" bs=512 count=100 conv=notrunc
  dd if=/dev/zero of="${SELECTED_MAIN_DISK}" bs=512 seek="${sector_count}" count=100 conv=notrunc

  partprobe "${SELECTED_MAIN_DISK}" 2> /dev/null || true

  if [[ "${SELECTED_SECOND_DISK}" != "ignore" ]]; then
    print_info "    Wiping second disk partitions"
    wipefs --all --force "${SELECTED_SECOND_DISK}*" 2> /dev/null || true
    wipefs --all --force "${SELECTED_SECOND_DISK}" || true

    local second_sector_count
    second_sector_count=$(blockdev --getsz "${SELECTED_SECOND_DISK}")
    second_sector_count=$((second_sector_count - 100))

    dd if=/dev/zero of="${SELECTED_SECOND_DISK}" bs=512 count=100 conv=notrunc
    dd if=/dev/zero of="${SELECTED_SECOND_DISK}" bs=512 seek="${second_sector_count}" count=100 conv=notrunc

    partprobe "${SELECTED_SECOND_DISK}" 2> /dev/null || true
  fi
}

create_main_partitions() {
  print_info "Creating main partitions"

  print_status "    Creating partition table"
  parted --script -a optimal "${SELECTED_MAIN_DISK}" mklabel gpt

  # Note: In this script the first two partitions are always "system" partitions while
  # the third partition (such as /dev/sda3) will ALWAYS be the main data partition.

  print_status "    Boot partitions"
  if [[ "${UEFI}" == "1" ]]; then
    # EFI partition (512mb)
    parted --script -a optimal "${SELECTED_MAIN_DISK}" mkpart "esp" fat32 0 512MiB
    parted --script -a optimal "${SELECTED_MAIN_DISK}" set 1 esp on
    # Boot partition (1gb)
    parted --script -a optimal "${SELECTED_MAIN_DISK}" mkpart "boot" ext4 512MiB 1536MiB

    print_status "    Main Partition"
    parted --script -a optimal "${SELECTED_MAIN_DISK}" mkpart "os" ext4 1536MiB 100%
  else
    # BIOS Grub partition (1mb)
    parted --script -a optimal "${SELECTED_MAIN_DISK}" mkpart "grub" fat32 0 1MiB
    parted --script -a optimal "${SELECTED_MAIN_DISK}" set 1 bios_grub on
    # Boot partition (1gb)
    parted --script -a optimal "${SELECTED_MAIN_DISK}" mkpart "boot" ext4 1MiB 1025MiB
    parted --script -a optimal "${SELECTED_MAIN_DISK}" set 2 boot on

    print_status "    Main Partition"
    parted --script -a optimal "${SELECTED_MAIN_DISK}" mkpart "os" ext4 1025MiB 100%
  fi

  partprobe "${SELECTED_MAIN_DISK}" 2> /dev/null || true
}

create_secondary_partitions() {
  if [[ "${SELECTED_SECOND_DISK}" != "ignore" ]]; then
    print_info "Creating secondary disk partitions"

    print_status "    Creating partition table"
    parted --script -a optimal "${SELECTED_SECOND_DISK}" mklabel gpt

    print_status "    Secondary Partition"
    parted --script -a optimal "${SELECTED_SECOND_DISK}" mkpart "data" xfs 0 100%
    if [[ "${AUTO_ENCRYPT_DISKS}" == "0" ]]; then
      parted --script -a optimal "${SELECTED_SECOND_DISK}" set 1 lvm on
    fi

    partprobe "${SELECTED_SECOND_DISK}" 2> /dev/null || true
  fi
}

query_disk_partitions() {
  print_info "Querying partitions"

  # Sleeping to resolve some race conditions with the disk partitions being read incorrectly
  sleep 1s

  local disk_part_string
  local disk_parts=()
  disk_part_string=$(lsblk -lnp --output "PATH,TYPE" "${SELECTED_MAIN_DISK}" | grep -F "part" | cut -d' ' -f 1)
  while IFS= read -r -d $'\n' line; do
    disk_parts+=("${line}")
  done <<< "${disk_part_string}"

  if [[ "${#disk_parts[@]}" -ne 3 ]]; then
    error_msg "Invalid number of partitions on main disk, something went wrong."
  fi

  MAIN_DISK_FIRST_PART="${disk_parts[0]}"
  write_debug "MAIN_DISK_FIRST_PART=${MAIN_DISK_FIRST_PART}"

  MAIN_DISK_SECOND_PART="${disk_parts[1]}"
  write_debug "MAIN_DISK_SECOND_PART=${MAIN_DISK_SECOND_PART}"

  MAIN_DISK_THIRD_PART="${disk_parts[2]}"
  write_debug "MAIN_DISK_THIRD_PART=${MAIN_DISK_THIRD_PART}"

  if [[ "${MAIN_DISK_FIRST_PART}" == "" || "${MAIN_DISK_SECOND_PART}" == "" || "${MAIN_DISK_THIRD_PART}" = "" ]]; then
    error_msg "Unable to read main disk partition information."
  fi

  if [[ "${SELECTED_SECOND_DISK}" != "ignore" ]]; then
    local second_disk_part_string
    local second_disk_parts=()
    second_disk_part_string=$(lsblk -lnp --output PATH,TYPE "${SELECTED_SECOND_DISK}" | grep -F "part" | cut -d' ' -f 1)
    while IFS= read -r -d $'\n' line; do
      second_disk_parts+=("${line}")
    done <<< "${second_disk_part_string}"
    # convert to an array
    if [[ "${#second_disk_parts[@]}" -ne 1 ]]; then
      error_msg "Invalid number of partitions on second disk, something went wrong."
    fi

    SECOND_DISK_FIRST_PART="${second_disk_parts[0]}"
  else
    SECOND_DISK_FIRST_PART="/zzz/zzz"
  fi

  if [[ "${SECOND_DISK_FIRST_PART}" == "" ]]; then
    error_msg "Unable to read second disk partition information."
  fi
  write_debug "SECOND_DISK_FIRST_PART=${SECOND_DISK_FIRST_PART}"
}

setup_encryption() {
  ENCRYPTION_FILE=""
  SECONDARY_FILE=""

  if [[ "${AUTO_ENCRYPT_DISKS}" == "1" ]]; then
    print_info "Setting up encryption"

    case "${AUTO_DISK_PWD}" in
      file)
        encrypt_main_generated_file
        ;;

      /* | http://* | https://* | ftp://* | ftps://* | sftp://* | file://*)
        encrypt_main_provided_file
        ;;

      *)
        encrypt_main_passphrase
        ;;
    esac

    if [[ "${SELECTED_SECOND_DISK}" != "ignore" ]]; then
      print_status "    Generating keyfile for second disk"
      SECONDARY_FILE=$(mktemp)

      openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -out "${SECONDARY_FILE}"

      print_status "    Encrypting second disk"
      cryptsetup --batch-mode -s 512 --iter-time 5000 --type luks2 luksFormat "${SECOND_DISK_FIRST_PART}" "${SECONDARY_FILE}"

      print_status "    Opening second disk"
      cryptsetup open --type luks --key-file "${SECONDARY_FILE}" "${SECOND_DISK_FIRST_PART}" cryptdata
    fi
  fi
}

encrypt_main_generated_file() {
  print_status "    Generating encryption file"

  ENCRYPTION_FILE=$(mktemp)
  write_log "ENCRYPTION_FILE=${ENCRYPTION_FILE}"

  openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -out "${ENCRYPTION_FILE}"

  print_status "    Encrypting main disk"
  cryptsetup --batch-mode -s 512 --iter-time 5000 --type luks2 luksFormat "${MAIN_DISK_THIRD_PART}" "${ENCRYPTION_FILE}"

  print_status "    Opening main disk"
  cryptsetup open --type luks --key-file "${ENCRYPTION_FILE}" "${MAIN_DISK_THIRD_PART}" cryptroot
}

encrypt_main_provided_file() {
  ENCRYPTION_FILE="${AUTO_DISK_PWD}"
  print_status "    Using provided encryption file"

  if [[ "${ENCRYPTION_FILE}" != /* ]]; then
    local download_file="downloaded-key"
    wget -O "${download_file}" "${ENCRYPTION_FILE}"
    ENCRYPTION_FILE="${download_file}"
  fi

  print_status "    Encrypting main disk"
  cryptsetup --batch-mode -s 512 --iter-time 5000 --type luks2 luksFormat "${MAIN_DISK_THIRD_PART}" "${ENCRYPTION_FILE}"

  print_status "    Opening main disk"
  cryptsetup open --type luks --key-file "${ENCRYPTION_FILE}" "${MAIN_DISK_THIRD_PART}" cryptroot
}

encrypt_main_passphrase() {
  print_status "    Using provided encryption passphrase"
  ENCRYPTION_FILE="password"

  print_status "    Encrypting main disk"
  echo -n "${AUTO_DISK_PWD}" | cryptsetup --batch-mode -s 512 --iter-time 5000 --type luks2 luksFormat "${MAIN_DISK_THIRD_PART}" -

  print_status "    Opening main disk"
  echo -n "${AUTO_DISK_PWD}" | cryptsetup open --type luks "${MAIN_DISK_THIRD_PART}" cryptroot --key-file -
}

setup_lvm() {
  if [[ "${SELECTED_SECOND_DISK}" != "ignore" ]]; then
    print_info "Setting up LVM"

    local pv_volume
    if [[ "${AUTO_ENCRYPT_DISKS}" == "1" ]]; then
      pv_volume="/dev/mapper/cryptdata"
    else
      pv_volume="${SECOND_DISK_FIRST_PART}"
    fi

    pvcreate "${pv_volume}"
    vgcreate "vg_data" "${pv_volume}"

    if [[ "${AUTO_USE_DATA_DIR}" == "1" ]]; then
      lvcreate -l 50%VG "vg_data" -n lv_home
      lvcreate -l 30%VG "vg_data" -n lv_data
    else
      lvcreate -l 80%VG "vg_data" -n lv_home
    fi
  fi
}

format_partitions() {
  print_info "Formatting partitions"

  # Sleeping to resolve some race conditions with the disk partitions being read incorrectly
  sleep 1s

  if [[ "${UEFI}" == "1" ]]; then
    # Format the EFI partition
    mkfs.vfat -n EFI "${MAIN_DISK_FIRST_PART}"
  fi

  # Now boot...
  mkfs.ext4 "${MAIN_DISK_SECOND_PART}"

  # Now root...
  local root_volume
  if [[ "${AUTO_ENCRYPT_DISKS}" == "1" ]]; then
    root_volume="/dev/mapper/cryptroot"
  else
    root_volume="${MAIN_DISK_THIRD_PART}"
  fi

  mkfs.ext4 "${root_volume}"

  if [[ "${SELECTED_SECOND_DISK}" != "ignore" ]]; then
    mkfs.xfs "/dev/mapper/vg_data-lv_home"
    if [[ "${AUTO_USE_DATA_DIR}" == "1" ]]; then
      mkfs.xfs "/dev/mapper/vg_data-lv_data"
    fi
  fi
}

mount_partitions() {
  print_info "Mounting partitions"

  # First root
  local root_volume
  if [[ "${AUTO_ENCRYPT_DISKS}" == "1" ]]; then
    root_volume="/dev/mapper/cryptroot"
  else
    root_volume="${MAIN_DISK_THIRD_PART}"
  fi
  mount -t ext4 -o errors=remount-ro "${root_volume}" /mnt

  # Now boot
  mkdir /mnt/boot
  mount -t ext4 "${MAIN_DISK_SECOND_PART}" /mnt/boot

  if [[ "${UEFI}" == "1" ]]; then
    # And EFI
    mkdir /mnt/boot/efi
    mount -t vfat "${MAIN_DISK_FIRST_PART}" /mnt/boot/efi
  fi

  if [[ "${SELECTED_SECOND_DISK}" != "ignore" ]]; then
    mkdir /mnt/home
    mount -t xfs "/dev/mapper/vg_data-lv_home" /mnt/home

    if [[ "${AUTO_USE_DATA_DIR}" == "1" ]]; then
      mkdir /mnt/data
      mount -t xfs "/dev/mapper/vg_data-lv_data" /mnt/data
    fi
  else
    if [[ "${AUTO_USE_DATA_DIR}" == "1" ]]; then
      # Just make a data directory on the root
      mkdir /mnt/data
    fi
  fi
}

### END: Disk And Partition Functions

### START: Install System

install_base_system() {
  print_info "Installing base system"

  case "${AUTO_INSTALL_OS}" in
    debian)
      install_base_system_debian
      ;;

    ubuntu)
      install_base_system_ubuntu
      ;;

    *)
      error_msg "ERROR! OS to install not supported: '${AUTO_INSTALL_OS}'"
      ;;
  esac
}

install_base_system_debian() {
  print_status "    Installing Debian"

  write_log "Running debootstrap"

  DEBOOTSTRAP_DIR="/debootstrap" /debootstrap/debootstrap --arch "${DPKG_ARCH}" \
    --include=lsb-release,tasksel "${SELECTED_INSTALL_EDITION}" "/mnt" "${SELECTED_REPO_URL}"

  write_log "Debootstrap complete"

  # Configure apt for the rest of the installations
  configure_apt_debian
  configure_locale
  configure_keymap

  # Updates, just in case
  chroot_run_updates

  # Standard server setup
  arch-chroot /mnt tasksel --new-install install standard

  # Can't use branches like "stable" or "oldstable" must convert to the codename like "bullseye" or "bookworm"
  local edition
  edition=$(arch-chroot /mnt lsb_release -c -s)

  # Kernel & Firmware
  local kernel_to_install="default"
  if [[ "${AUTO_KERNEL_VERSION}" == "backport" || "${AUTO_KERNEL_VERSION}" == "backports" ]]; then
    # Will need to regularly update the codename for testing here, currently "trixie"
    local dont_support_backports=("trixie" "testing" "sid" "unstable" "rc-buggy" "experimental")
    get_exit_code contains_element "${SELECTED_INSTALL_EDITION}" "${dont_support_backports[@]}"
    if [[ ! "${EXIT_CODE}" == "0" ]]; then
      # Check to see the package exists in backports, if not we'll just install the default kernel
      if package_exists "linux-image-${DPKG_ARCH}/${edition}-backports"; then
        kernel_to_install="backports"
      else
        write_log "Backport kernel was requested, but no backport kernel found.  Falling back to default kernel."
      fi
    else
      write_log "Backport kernel was requested, but OS edition does not support backports.  Falling back to default kernel."
    fi
  fi

  write_log "Kernel requested: '${AUTO_KERNEL_VERSION}'"
  write_log "Kernel selected: '${kernel_to_install}'"

  # Now install the kernel
  write_log "Installing Kernel"
  case "${kernel_to_install}" in
    default)
      chroot_install "linux-image-${DPKG_ARCH}" "linux-headers-${DPKG_ARCH}" firmware-linux
      ;;

    backports)
      arch-chroot /mnt apt-get -y -q install -t "${edition}-backports" \
        "linux-image-${DPKG_ARCH}" "linux-headers-${DPKG_ARCH}" firmware-linux
      ;;

    *)
      error_msg "ERROR! Unable to determine kernel to install."
      ;;
  esac
  write_log "Kernel install complete"
}

install_base_system_ubuntu() {
  print_status "    Installing Ubuntu"

  write_log "Running debootstrap"

  DEBOOTSTRAP_DIR="/debootstrap" /debootstrap/debootstrap --arch "${DPKG_ARCH}" \
    --include=lsb-release "${SELECTED_INSTALL_EDITION}" "/mnt" "${SELECTED_REPO_URL}"

  write_log "Debootstrap complete"

  # Configure apt for the rest of the installations
  configure_apt_ubuntu
  configure_locale
  configure_keymap

  # Updates, just in case
  chroot_run_updates

  # Standard server setup
  #arch-chroot /mnt tasksel --new-install install standard

  # The HWE kernels use the Ubuntu version numbers rather than the codename
  local release_ver
  release_ver=$(arch-chroot /mnt lsb_release -r -s)

  local hwe_edge_exists=0
  if package_exists "linux-generic-hwe-${release_ver}-edge"; then
    hwe_edge_exists=1
  fi

  local hwe_exists=0
  if package_exists "linux-generic-hwe-${release_ver}"; then
    hwe_exists=1
  fi

  local kernel_to_install="default"
  if [[ "${AUTO_KERNEL_VERSION}" == "hwe-edge" ]]; then
    if [[ "${hwe_edge_exists}" == "0" ]]; then
      kernel_to_install="hwe-edge"
    elif [[ "${hwe_exists}" == "0" ]]; then
      kernel_to_install="hwe"
      write_log "The hwe-edge kernel was requested, but the package was not found.  Found a standard hwe kernel instead and choosing that for install."
    else
      write_log "The hwe-edge kernel was requested, but no hwe packages were found.  Falling back to the default kernel."
    fi
  elif [[ "${AUTO_KERNEL_VERSION}" == "hwe" ]]; then
    if [[ "${hwe_exists}" == "0" ]]; then
      kernel_to_install="hwe"
    else
      write_log "The hwe kernel was requested, but no hwe package was found.  Falling back to the default kernel."
    fi
  fi

  write_log "Kernel requested: '${AUTO_KERNEL_VERSION}'"
  write_log "Kernel selected: '${kernel_to_install}'"

  # Now install the kernel
  write_log "Installing Kernel"
  case "${kernel_to_install}" in
    default)
      chroot_install linux-generic linux-firmware
      ;;

    hwe)
      chroot_install "linux-generic-hwe-${release_ver}" linux-firmware
      ;;

    hwe-edge)
      chroot_install "linux-generic-hwe-${release_ver}-edge" linux-firmware
      ;;

    *)
      error_msg "ERROR! Unable to determine kernel to install."
      ;;
  esac
  write_log "Kernel install complete"
}

install_bootloader() {
  print_info "Installing bootloader"

  if [[ "${UEFI}" == "1" ]]; then
    install_bootloader_efi
  else
    install_bootloader_bios
  fi
  write_log "Bootloader install complete"
}

install_bootloader_efi() {
  print_info "Installing bootloader (UEFI)"

  chroot_install efibootmgr "grub-efi-${DPKG_ARCH}" "grub-efi-${DPKG_ARCH}-signed" shim-signed mokutil

  if [[ "${AUTO_INSTALL_OS}" == "debian" ]]; then
    chroot_install "shim-helpers-${DPKG_ARCH}-signed"
  fi

  local target
  case "${DPKG_ARCH}" in
    i386)
      target="i386-pc"
      ;;
    arm)
      target="arm-efi"
      ;;
    arm64)
      target="arm64-efi"
      ;;
    *)
      target="x86_64-efi"
      ;;
  esac

  arch-chroot /mnt grub-install "--target=${target}" --efi-directory=/boot/efi --bootloader-id="${AUTO_INSTALL_OS}" --recheck --no-nvram "${SELECTED_MAIN_DISK}"

  arch-chroot /mnt update-grub
}

install_bootloader_bios() {
  print_info "Installing bootloader (BIOS)"

  print_warning "BIOS support is DEPRECATED and not well tested"

  chroot_install grub-pc

  arch-chroot /mnt grub-install "${SELECTED_MAIN_DISK}"

  arch-chroot /mnt update-grub
}

### END: Install System

### START: System Configuration

configure_locale() {
  print_info "Configuring locale"

  chroot_install locales

  # Always enable en_US.UTF-8
  sed -i '/en_US.UTF-8/ c\en_US.UTF-8 UTF-8' /mnt/etc/locale.gen
  # Now enable their locale
  sed -i -E "s/^#\s${AUTO_LOCALE}\s(.*)$/${AUTO_LOCALE} \1/" /mnt/etc/locale.gen
  arch-chroot /mnt dpkg-reconfigure --frontend=noninteractive locales

  arch-chroot /mnt update-locale --reset LANG="${AUTO_LOCALE}" LANGUAGE="${AUTO_LANGUAGE}"
}

configure_apt_debian() {
  print_info "Configuring APT (Debian)"

  # Backup the one originally installed
  mv /mnt/etc/apt/sources.list /mnt/etc/apt/sources.list.bootstrapped

  local components="main contrib non-free non-free-firmware"

  # This list should shrink over time until all releases support the new "non-free-firmware" component that was introduced in "bookworm"
  local old_editions=("oldoldstable" "buster" "oldstable" "bullseye")
  get_exit_code contains_element "${SELECTED_INSTALL_EDITION}" "${old_editions[@]}"
  if [[ "${EXIT_CODE}" == "0" ]]; then
    components="main contrib non-free"
  fi

  # Write out sources
  echo "deb ${SELECTED_REPO_URL} ${SELECTED_INSTALL_EDITION} ${components}" > /mnt/etc/apt/sources.list

  # Alt repos
  local dont_support_alt_repos=("sid" "unstable" "rc-buggy" "experimental")
  get_exit_code contains_element "${SELECTED_INSTALL_EDITION}" "${dont_support_alt_repos[@]}"
  if [[ ! "${EXIT_CODE}" == "0" ]]; then
    # Alt repos
    {
      # The security repo MUST come from the main sources as mirrors will not contain a copy
      echo "deb http://deb.debian.org/debian-security ${SELECTED_INSTALL_EDITION}-security ${components}"
      echo "deb ${SELECTED_REPO_URL} ${SELECTED_INSTALL_EDITION}-updates ${components}"
    } >> /mnt/etc/apt/sources.list
  fi

  # Will need to regularly update the codename for testing here, currently "trixie"
  local dont_support_backports=("trixie" "testing" "sid" "unstable" "rc-buggy" "experimental")
  get_exit_code contains_element "${SELECTED_INSTALL_EDITION}" "${dont_support_alt_repos[@]}"
  if [[ ! "${EXIT_CODE}" == "0" ]]; then
    # Can't use branches like "stable" or "oldstable" must convert to the codename like "bullseye" or "bookworm"
    local edition
    edition=$(arch-chroot /mnt lsb_release -c -s)

    # Now backports
    echo "deb ${SELECTED_REPO_URL} ${edition}-backports ${components}" > /mnt/etc/apt/sources.list.d/debian-backports.list
  fi

  chroot_run_updates
}

configure_apt_ubuntu() {
  print_info "Configuring APT (Ubuntu)"

  # Backup the one originally installed
  mv /mnt/etc/apt/sources.list /mnt/etc/apt/sources.list.bootstrapped

  # Write out sources
  {
    echo "deb ${SELECTED_REPO_URL} ${SELECTED_INSTALL_EDITION} main restricted universe multiverse"
    echo "deb ${SELECTED_REPO_URL} ${SELECTED_INSTALL_EDITION}-updates main restricted universe multiverse"
    echo "deb ${SELECTED_REPO_URL} ${SELECTED_INSTALL_EDITION}-backports main restricted universe multiverse"
    echo "deb ${SELECTED_REPO_URL} ${SELECTED_INSTALL_EDITION}-security main restricted universe multiverse"
  } > /mnt/etc/apt/sources.list

  chroot_run_updates
}

configure_keymap() {
  print_info "Configure keymap"

  chroot_install console-setup console-data

  loadkeys "${AUTO_KEYMAP}"
  arch-chroot /mnt loadkeys "${AUTO_KEYMAP}"

  echo "KEYMAP=${AUTO_KEYMAP}" > /mnt/etc/vconsole.conf
  echo "FONT=Lat15-Terminus${CONSOLE_FONT_SIZE}" >> /mnt/etc/vconsole.conf

  sed -i "/^CHARMAP=/ c\CHARMAP=\"${SELECTED_CHARMAP}\"" /mnt/etc/default/console-setup
  sed -i '/^CODESET=/ c\CODESET="guess"' /mnt/etc/default/console-setup
  sed -i '/^FONTFACE=/ c\FONTFACE="Terminus"' /mnt/etc/default/console-setup
  sed -i "/^FONTSIZE=/ c\FONTSIZE=\"${CONSOLE_FONT_SIZE}\"" /mnt/etc/default/console-setup

  setfont "Lat15-Terminus${CONSOLE_FONT_SIZE}"
}

configure_encryption() {
  if [[ "${AUTO_ENCRYPT_DISKS}" == "1" ]]; then
    print_info "Configuring encryption"

    mkdir -p /mnt/etc/keys

    local main_keyfile="none"
    if [[ "${ENCRYPTION_FILE}" != "password" ]]; then
      main_keyfile="/mnt/boot/root.key"
      mv "${ENCRYPTION_FILE}" "${main_keyfile}"
      chmod 0400 "${main_keyfile}"
    fi

    local main_uuid
    local boot_uuid
    main_uuid=$(blkid -o value -s UUID "${MAIN_DISK_THIRD_PART}")
    boot_uuid=$(blkid -o value -s UUID "${MAIN_DISK_SECOND_PART}")

    local discard_option=""
    local disk_gran
    disk_gran=$(lsblk -ndpl --output NAME,DISC-GRAN | grep -i "${SELECTED_MAIN_DISK}" | tr -s ' ' | cut -d' ' -f 2 || true)
    if [[ "${disk_gran}" != "0B" ]]; then
      local discard_option=",discard"
    fi

    if [[ "${ENCRYPTION_FILE}" != "password" ]]; then
      echo "cryptroot UUID=${main_uuid} /dev/disk/by-uuid/${boot_uuid}:root.key luks,initramfs,keyscript=/lib/cryptsetup/scripts/passdev,tries=3${discard_option}" >> /mnt/etc/crypttab
    else
      echo "cryptroot UUID=${main_uuid} none luks,initramfs,tries=3${discard_option}" >> /mnt/etc/crypttab
    fi

    fix_systemd_encryption_bug

    if [[ "${SELECTED_SECOND_DISK}" != "ignore" && "${SECONDARY_FILE}" != "" ]]; then
      local second_key="/etc/keys/secondary.key"
      mv "${SECONDARY_FILE}" "/mnt${second_key}"
      chmod 0400 "/mnt${second_key}"

      local second_uuid
      second_uuid=$(blkid -o value -s UUID "${SECOND_DISK_FIRST_PART}")

      local discard_option=""
      local disk_gran
      disk_gran=$(lsblk -ndpl --output NAME,DISC-GRAN | grep -i "${SELECTED_SECOND_DISK}" | tr -s ' ' | cut -d' ' -f 2 || true)
      if [[ "${disk_gran}" != "0B" ]]; then
        local discard_option=",discard"
      fi

      echo "cryptdata UUID=${second_uuid} ${second_key} luks,tries=3${discard_option}" >> /mnt/etc/crypttab
    fi
  fi

  # If a multi-disk system, configure LVM to issue discards, regardless of encryption
  if [[ "${SELECTED_SECOND_DISK}" != "ignore" ]]; then
    sed -i 's/issue_discards = 0/issue_discards = 1/g' /mnt/etc/lvm/lvm.conf
  fi

  # Ensure the fstrim timer is enabled
  arch-chroot /mnt systemctl enable fstrim.timer
}

fix_systemd_encryption_bug() {
  # BAF - There is a major bug in Systemd where it doesn't handle the passdev syntax for the key.  It expects the OPPOSITE where the first part is the file path, then a colon, then a disk identifier like UUID=xxx or LABEL=xxx.  Passdev uses a format of a disk identifier (usually a persistent devices /dev/disk/xxx, then a colon, then the path to the file.
  #
  # Systemd calls systemd-cryptsetup-generator on boot and generates some files.  We can manually call that, edit one of the files and copy it to /etc/systemd/system to override what the generator creates.
  #
  # Lastly, the chroot environment isn't running systemd so we can't do it in there.  Instead, we have to set up a script to run on boot which takes care of everything.

  write_log "Applying systemd fix for encryption"

  cat <<- 'EOF' > /mnt/etc/systemd/system/cryptsetup-first-boot.service
[Unit]
Description=First boot script to fix systemd encryption issue
ConditionPathExists=/usr/local/sbin/fix-systemd-encryption-issue.sh

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/fix-systemd-encryption-issue.sh

[Install]
WantedBy=default.target
EOF

  cat <<- 'EOF' > /mnt/usr/local/sbin/fix-systemd-encryption-issue.sh
#!/usr/bin/env sh

# Run the generator
/lib/systemd/system-generators/systemd-cryptsetup-generator
if [ ! -f "/tmp/systemd-cryptsetup@cryptroot.service" ]
then
  exit 1
fi

dest_file="/etc/systemd/system/systemd-cryptsetup@cryptroot.service"

cp "/tmp/systemd-cryptsetup@cryptroot.service" "${dest_file}"

# Now edit the file to remove the offending lines
sed -i '/^After=dev-disk-by.*root\.key\.device$/d' "${dest_file}"
sed -i '/^Requires=dev-disk-by.*root\.key\.device$/d' "${dest_file}"

# Clean up the systemctl service
systemctl disable cryptsetup-first-boot.service
rm /etc/systemd/system/cryptsetup-first-boot.service

# Clean up by deleting this script
rm $0
EOF

  chmod 0754 /mnt/usr/local/sbin/fix-systemd-encryption-issue.sh
  arch-chroot /mnt systemctl enable cryptsetup-first-boot.service
}

configure_fstab() {
  print_info "Configuring fstab"

  genfstab -t UUID -p /mnt > /mnt/etc/fstab
}

configure_hostname() {
  print_info "Configuring hostname"

  local hostname
  hostname="${AUTO_HOSTNAME}"
  if [[ "${hostname}" == "" ]]; then
    hostname="${AUTO_INSTALL_OS}-$((1 + RANDOM % 100000))"
  fi

  echo "${hostname}" > /mnt/etc/hostname

  local the_line
  if [[ "${AUTO_DOMAIN}" == "" ]]; then
    the_line="127.0.1.1 ${hostname}"
  else
    the_line="127.0.1.1 ${hostname} ${hostname}.${AUTO_DOMAIN}"
  fi

  if grep -q '^127.0.1.1[[:blank:]]' /mnt/etc/hosts; then
    # Update the line
    sed -i "/^127.0.1.1[[:blank:]]/ c\\${the_line}" /mnt/etc/hosts
  else
    # Add the line
    echo -E "${the_line}" >> /mnt/etc/hosts
  fi
}

configure_timezone() {
  print_info "Configuring timezone"

  # The timezone file
  echo "${AUTO_TIMEZONE}" | tee /mnt/etc/timezone

  # Ntp setup
  sed -i -E 's/^#FallbackNTP=(.*)$/FallbackNTP=\1/' /mnt/etc/systemd/timesyncd.conf

  cat <<- 'EOF' > /mnt/etc/systemd/system/timezone-first-boot.service
[Unit]
Description=First boot script to setup timezone
ConditionPathExists=/usr/local/sbin/setup-timezone.sh

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/setup-timezone.sh

[Install]
WantedBy=default.target
EOF

  cat <<- 'EOF' > /mnt/usr/local/sbin/setup-timezone.sh
#!/usr/bin/env sh

the_timezone=$(cat /etc/timezone)

hwclock --systohc --utc --update-drift

timedatectl set-local-rtc 0
timedatectl set-timezone "${the_timezone}"
timedatectl set-ntp true

# Clean up the systemctl service
systemctl disable timezone-first-boot.service
rm /etc/systemd/system/timezone-first-boot.service

# Clean up by deleting this script
rm $0
EOF

  chmod 0754 /mnt/usr/local/sbin/setup-timezone.sh
  arch-chroot /mnt systemctl enable timezone-first-boot.service
}

configure_boot() {
  print_info "Configuring boot"

  # Make sure lz4 is installed
  chroot_install lz4

  # Set that as the compression to use
  sed -i '/^COMPRESS=/ c\COMPRESS=lz4' /mnt/etc/initramfs-tools/initramfs.conf

  # Update grub
  local grub_cmdline_linux_default='GRUB_CMDLINE_LINUX_DEFAULT="quiet splash iommu=pt"'
  # if [[ "${AUTO_ENCRYPT_DISKS}" == "1" ]]
  # then
  #   grub_cmdline_linux_default='GRUB_CMDLINE_LINUX_DEFAULT="quiet splash iommu=pt rd.luks.options=discard"'
  # fi
  sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=.*$/${grub_cmdline_linux_default}/g" /mnt/etc/default/grub

  sed -i -E '/GRUB_GFXMODE=/ c\GRUB_GFXMODE=1024x768x32' /mnt/etc/default/grub

  # Run updates
  arch-chroot /mnt update-initramfs -u
  arch-chroot /mnt update-grub
}

configure_swap() {
  print_info "Configuring swap"

  # NOTE: The default calculated size is the sqrt of total ram size with a floor of 2gb.  Generally, this will NOT be enough swap space to support hibernation.  To support hibernation increasing the swapfile size after bootstrapping will be required.

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

  # Make sure the minimum is 2gb
  if [[ "${size}" -lt "1" ]]; then
    size="2"
  fi

  # Create a swap file
  fallocate -l "${size}G" /mnt/swapfile
  chmod 600 /mnt/swapfile
  mkswap /mnt/swapfile

  # Remove any previous swap
  sed -i '/[[:blank:]]swap[[:blank:]]/ d' /mnt/etc/fstab
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

  chmod 0600 /mnt/etc/netplan/01-network-manage-all.yaml
  arch-chroot /mnt netplan generate
}

configure_virtualization() {
  print_info "Checking virtualization"
  local detected_virt
  detected_virt=$(systemd-detect-virt || true)
  if [[ "${detected_virt}" == "oracle" && "${UEFI}" = 1 && "${AUTO_INSTALL_OS}" == "debian" ]]; then
    # On virtualbox we MUST configure this or the system won't boot correctly.  I am doing the absolute minimum I can here to get things working.  Any other virtualization configurations should be done post bootstrap.

    print_info "Setting up Virtualbox EFI"

    if [[ ! -f "/mnt/boot/efi/startup.nsh" ]]; then
      echo "FS0:" > /mnt/boot/efi/startup.nsh
      echo "\\EFI\\${AUTO_INSTALL_OS}\\grubx64.efi" >> /mnt/boot/efi/startup.nsh
    fi

    local boot_imgs
    boot_imgs=$(arch-chroot /mnt efibootmgr)
    if ! echo "${boot_imgs}" | grep -i -q "\* ${AUTO_INSTALL_OS}"; then
      efi_disk=$(lsblk -np -o PKNAME,MOUNTPOINT | grep -i "/mnt/boot/efi" | cut -d' ' -f 1)
      efi_device=$(lsblk -np -o PATH,MOUNTPOINT | grep -i "/mnt/boot/efi" | cut -d' ' -f 1)
      efi_part="$(udevadm info --query=property --name="${efi_device}" | grep -i ID_PART_ENTRY_NUM | cut -d= -f 2)"

      arch-chroot /mnt efibootmgr -c -d "${efi_disk}" -p "${efi_part}" -l "\\EFI\\${AUTO_INSTALL_OS}\\grubx64.efi" -L "${AUTO_INSTALL_OS}"
    fi
  fi

  if [[ "${detected_virt}" == "oracle" && "${UEFI}" = 1 && "${AUTO_INSTALL_OS}" == "ubuntu" ]]; then
    arch-chroot /mnt efibootmgr -n 0002
  fi
}

### END: System Configuration

### START: Install Applications

install_applications_common() {
  print_info "Installing common applications"

  # Required in all environments, many to true up standard server installation
  chroot_install apt-transport-https ca-certificates curl wget gnupg lsb-release build-essential dkms sudo acl git vim-nox python3-dev python3-keyring python3-pip python-is-python3 pipx software-properties-common apparmor ssh locales console-setup console-data lz4 network-manager netplan.io cryptsetup cryptsetup-initramfs xfsprogs dictionaries-common iamerican ibritish discover discover-data laptop-detect usbutils eject util-linux-locales man-db tasksel fbset dosfstools

  setfont "Lat15-Terminus${CONSOLE_FONT_SIZE}"

  if [[ "${SELECTED_SECOND_DISK}" != "ignore" ]]; then
    # Only need LVM for multi-disk installations
    chroot_install lvm2
  fi
}

install_applications_debian() {
  if [[ "${AUTO_INSTALL_OS}" == "debian" ]]; then
    print_info "Installing Debian specific applications"

    chroot_install installation-report
  fi
}

install_applications_ubuntu() {
  if [[ "${AUTO_INSTALL_OS}" == "ubuntu" ]]; then
    print_info "Installing Ubuntu specific applications"

    chroot_install language-pack-en
  fi
}

install_applications_extra_packages() {
  if [[ "${AUTO_EXTRA_PACKAGES}" != "" ]]; then
    print_info "Installing extra packages requested"

    chroot_install "${AUTO_EXTRA_PACKAGES}"
  fi
}

install_configuration_management() {
  print_info "Installing configuration management software (if requested)"
  case "${AUTO_CONFIG_MANAGEMENT}" in
    ansible)
      chroot_install ansible ansible-mitogen dnspython
      ;;
    ansible-pip)
      arch-chroot /mnt pipx install --include-deps ansible
      arch-chroot /mnt pipx inject ansible mitogen
      arch-chroot /mnt pipx inject ansible cryptography
      arch-chroot /mnt pipx inject ansible paramiko
      arch-chroot /mnt pipx inject ansible dnspython
      ;;
    saltstack)
      install_salt
      ;;
    saltstack-repo)
      install_salt_from_repo
      ;;
    saltstack-bootstrap)
      install_salt_from_bootstrap
      ;;
    puppet)
      chroot_install puppet-agent
      ;;
    puppet-repo)
      install_puppet_from_repo
      ;;
    none)
      print_info "Skipping configuration management software installation, none selected."
      ;;
    *)
      print_info "Skipping configuration management software installation, invalid option."
      ;;
  esac
}

install_salt() {
  print_info "Installing saltstack"

  if package_exists "salt-minion"; then
    chroot_install salt-minion
  else
    print_warning "Salt package not available in default repositories, falling back to installing from Salt bootstrap."

    install_salt_from_bootstrap
  fi
}

install_salt_from_repo() {
  print_info "Installing saltstack from repo"

  mkdir -p /mnt/etc/apt/keyrings
  chmod "0755" /mnt/etc/apt/keyrings

  local salt_version="latest" # alternatively something like 3005
  local distro
  distro=$(arch-chroot /mnt lsb_release -i -s | tr "[:upper:]" "[:lower:]")
  local release
  release=$(arch-chroot /mnt lsb_release -r -s)
  local codename
  codename=$(arch-chroot /mnt lsb_release -c -s | tr "[:upper:]" "[:lower:]")

  # Salt only supports stable releases, not testing
  case "${codename}" in
    stable | testing | "${CURRENT_DEB_TESTING_CODENAME}")
      codename="${CURRENT_DEB_STABLE_CODENAME}"
      ;;
    *) ;;

  esac

  wget -O /mnt/etc/apt/keyrings/salt-archive-keyring.gpg "https://repo.saltproject.io/salt/py3/${distro}/${release}/${DPKG_ARCH}/${salt_version}/salt-archive-keyring.gpg"

  echo "deb [signed-by=/etc/apt/keyrings/salt-archive-keyring.gpg arch=${DPKG_ARCH}] https://repo.saltproject.io/salt/py3/${distro}/${release}/${DPKG_ARCH}/${salt_version} ${codename} main" | tee /mnt/etc/apt/sources.list.d/salt.list

  chroot_run_updates
  chroot_install salt-minion
}

install_salt_from_bootstrap() {
  print_info "Installing saltstack from bootstrap"

  curl -fsSL https://bootstrap.saltproject.io -o /home/user/install_salt.sh
  curl -fsSL https://bootstrap.saltproject.io/sha256 -o /home/user/install_salt_sha256

  local SHA_OF_FILE
  SHA_OF_FILE=$(sha256sum /home/user/install_salt.sh | cut -d' ' -f1)
  local SHA_FOR_VALIDATION
  SHA_FOR_VALIDATION=$(cat /home/user/install_salt_sha256)

  if [[ "${SHA_OF_FILE}" == "${SHA_FOR_VALIDATION}" ]]; then
    cp /home/user/install_salt.sh /mnt/usr/local/src/install_salt.sh
    sync

    arch-chroot /mnt sh /usr/local/src/install_salt.sh -P -X -x python3 stable
  else
    error_msg "WARNING: Salt script is corrupt or has been tampered with."
  fi
}

install_puppet_from_repo() {
  print_info "Installing puppet from repo"

  local codename
  codename=$(arch-chroot /mnt lsb_release -c -s)

  # Puppet only supports stable releases, not testing
  case "${codename}" in
    stable | testing | "${CURRENT_DEB_TESTING_CODENAME}")
      codename="${CURRENT_DEB_STABLE_CODENAME}"
      ;;
    *) ;;

  esac

  wget -O "/mnt/usr/local/src/puppet7-release-${codename}.deb" "https://apt.puppet.com/puppet7-release-${codename}.deb"
  sync

  arch-chroot /mnt dpkg -i "/usr/local/src/puppet7-release-${codename}.deb"

  chroot_run_updates
  chroot_install puppet-agent
  arch-chroot /mnt /opt/puppetlabs/bin/puppet resource service puppet ensure=running enable=true
}

### END: Install Applications

### START: User Configuration

setup_root() {
  if [[ "${AUTO_ROOT_DISABLED}" == "0" ]]; then
    print_info "Setting up root"

    # Unlock the root account
    passwd --root /mnt -u root

    local root_pwd
    root_pwd="${AUTO_ROOT_PWD}"
    # If they did not pass a password, default it to the provided user pwd,
    # otherwise to the install os name (debian, ubuntu)
    if [[ "${root_pwd}" == "" ]]; then
      if [[ "${AUTO_CREATE_USER}" == "1" && "${AUTO_USER_PWD}" != "" ]]; then
        root_pwd="${AUTO_USER_PWD}"
      else
        root_pwd="${AUTO_INSTALL_OS}"
      fi
    fi

    # Check if the password is encrypted
    if echo "${root_pwd}" | grep -q '^\$[[:digit:]]\$.*$'; then
      # Password is encrypted
      usermod --root /mnt --password "${root_pwd}" root
    else
      # Password is plaintext
      local encrypted
      encrypted=$(echo "${root_pwd}" | openssl passwd -6 -stdin)
      usermod --root /mnt --password "${encrypted}" root
    fi

    # If root is the only user, allow login with root through SSH.  Users can of course (and should) change this after initial boot, this just allows a remote connection to start things off.
    if [[ "${AUTO_CREATE_USER}" == "0" ]]; then
      sed -i -r '/^#?PermitRootLogin[[:blank:]](yes|no|prohibit-password)/ c\PermitRootLogin yes' /mnt/etc/ssh/sshd_config
    else
      sed -i -r '/^#?PermitRootLogin[[:blank:]](yes|no|prohibit-password)/ c\PermitRootLogin no' /mnt/etc/ssh/sshd_config
    fi
  fi
}

setup_data_directory() {
  print_info "In Setup Data Directory"
  if [[ "${AUTO_USE_DATA_DIR}" == "1" ]]; then
    groupadd --root /mnt --system data-user
    arch-chroot /mnt chown -R root:data-user /data
    arch-chroot /mnt chown -R root:data-user /srv
    chmod -R g+w /mnt/data
    chmod -R g+w /mnt/srv
  fi
}

setup_service_user() {
  print_info "In Setup Service User"

  if [[ "${AUTO_CREATE_SERVICE_ACCT}" == "1" ]]; then
    print_info "Setting up Service User"

    local user_name="svcacct"

    useradd --root /mnt --create-home --shell /bin/bash --system "${user_name}"
    #chfn --root /mnt --full-name "Service Account" "${user_name}"

    # Password will always be initialized to the install os (debian, ubuntu, etc.)
    local encrypted
    encrypted=$(echo "${AUTO_INSTALL_OS}" | openssl passwd -6 -stdin)
    usermod --root /mnt --password "${encrypted}" "${user_name}"

    # _ssh is the new name for the ssh group going forward, but I attempt to add both (ssh, _ssh) just in case
    groupsToAdd=(audio video plugdev netdev bluetooth kvm sudo ssh _ssh users data-user vboxsf)
    for groupToAdd in "${groupsToAdd[@]}"; do
      group_exists=$(arch-chroot /mnt getent group "${groupToAdd}" | wc -l || true)
      if [[ "${group_exists}" == "1" ]]; then
        usermod --root /mnt -a -G "${groupToAdd}" "${user_name}"
      fi
    done

    if [[ "${AUTO_SERVICE_ACCT_SSH_KEY}" != "" ]]; then
      print_info "Setting up Service Account ssh key"
      # Setup the SSH key
      mkdir -p "/mnt/home/${user_name}/.ssh"
      echo "${AUTO_SERVICE_ACCT_SSH_KEY}" | tee -a "/mnt/home/${user_name}/.ssh/authorized_keys"
      chmod "0644" "/mnt/home/${user_name}/.ssh/authorized_keys"
      chmod "0700" "/mnt/home/${user_name}/.ssh"
      chown -R "${user_name}:${user_name}" "/mnt/home/${user_name}/.ssh"
    fi

    # Setup Service Account for passwordless sudo
    cat << EOF > /mnt/etc/sudoers.d/svcacct
Defaults:svcacct !requiretty
svcacct ALL=(ALL) NOPASSWD: ALL
EOF

    chmod "0440" /mnt/etc/sudoers.d/svcacct
  fi
}

setup_user() {
  print_info "In Setup User"

  if [[ "${AUTO_CREATE_USER}" == "1" ]]; then
    print_info "Setting up user"

    local user_name
    local user_pwd
    user_name="${AUTO_USERNAME}"
    user_pwd="${AUTO_USER_PWD}"
    # If they did not pass a username, default it to the install os
    if [[ "${user_name}" == "" ]]; then
      user_name="${AUTO_INSTALL_OS}"
    fi
    # If they did not pass a password, default it to the install os
    if [[ "${user_pwd}" == "" ]]; then
      user_pwd="${AUTO_INSTALL_OS}"
    fi

    useradd --root /mnt --create-home --shell /bin/bash "${user_name}"
    #chfn --root /mnt --full-name "${user_name}" "${user_name}"

    # Check if the password is encrypted
    if echo "${user_pwd}" | grep -q '^\$[[:digit:]]\$.*$'; then
      # Password is encrypted
      usermod --root /mnt --password "${user_pwd}" "${user_name}"
    else
      # Password is plaintext
      local encrypted
      encrypted=$(echo "${user_pwd}" | openssl passwd -6 -stdin)
      usermod --root /mnt --password "${encrypted}" "${user_name}"
    fi

    # _ssh is the new name for the ssh group going forward, but I attempt to add both (ssh, _ssh) just in case
    groupsToAdd=(audio video plugdev netdev bluetooth kvm sudo ssh _ssh users data-user vboxsf)
    for groupToAdd in "${groupsToAdd[@]}"; do
      group_exists=$(arch-chroot /mnt getent group "${groupToAdd}" | wc -l || true)
      if [[ "${group_exists}" == "1" ]]; then
        usermod --root /mnt -a -G "${groupToAdd}" "${user_name}"
      fi
    done

    if [[ "${AUTO_USER_SSH_KEY}" != "" ]]; then
      print_info "Setting up user ssh key"
      # Setup the SSH key
      mkdir -p "/mnt/home/${user_name}/.ssh"
      echo "${AUTO_USER_SSH_KEY}" | tee -a "/mnt/home/${user_name}/.ssh/authorized_keys"
      chmod "0644" "/mnt/home/${user_name}/.ssh/authorized_keys"
      chmod "0700" "/mnt/home/${user_name}/.ssh"
      chown -R "${user_name}:${user_name}" "/mnt/home/${user_name}/.ssh"
    fi
  fi
}

### END: User Configuration

### START: Before, After, and First Boot Script Handling

run_before_script() {
  print_info "In Run Before Script"
  if [[ "${AUTO_BEFORE_SCRIPT}" != "" ]]; then
    local script="/home/user/scripts/before.script"
    mkdir -p "/home/user/scripts"
    if [[ "${AUTO_BEFORE_SCRIPT}" == /* ]]; then
      cp "${AUTO_BEFORE_SCRIPT}" "${script}"
    else
      wget -O "${script}" "${AUTO_BEFORE_SCRIPT}"
    fi
    chmod +x "${script}"

    get_exit_code "${script}"
    if [[ "${EXIT_CODE}" != "0" ]]; then
      error_msg "Before script returned a non-zero exit code: ${EXIT_CODE}"
    fi
  fi
}

run_after_script() {
  print_info "In Run After Script"
  if [[ "${AUTO_AFTER_SCRIPT}" != "" ]]; then
    local script="/home/user/scripts/after.script"
    mkdir -p "/home/user/scripts"
    if [[ "${AUTO_AFTER_SCRIPT}" == /* ]]; then
      cp "${AUTO_AFTER_SCRIPT}" "${script}"
    else
      wget -O "${script}" "${AUTO_AFTER_SCRIPT}"
    fi
    chmod +x "${script}"

    get_exit_code "${script}"
    if [[ "${EXIT_CODE}" != "0" ]]; then
      error_msg "After script returned a non-zero exit code: ${EXIT_CODE}"
    fi
  fi
}

setup_first_boot_script() {
  print_info "In Setup First Boot Script"
  if [[ "${AUTO_FIRST_BOOT_SCRIPT}" != "" ]]; then
    local script="/home/user/scripts/first-boot.script"
    mkdir -p "/home/user/scripts"
    if [[ "${AUTO_FIRST_BOOT_SCRIPT}" == /* ]]; then
      cp "${AUTO_FIRST_BOOT_SCRIPT}" "${script}"
    else
      wget -O "${script}" "${AUTO_FIRST_BOOT_SCRIPT}"
    fi
    cp "${script}" "/mnt/usr/local/sbin/first-boot.script"

    cat <<- 'EOF' > /mnt/etc/systemd/system/deb-install-first-boot.service
[Unit]
Description=Script to run on first boot of system.
Wants=network-online.target
After=network-online.target
ConditionPathExists=/usr/local/sbin/first-boot-wrapper.sh

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/first-boot-wrapper.sh

[Install]
WantedBy=default.target
EOF

    cat <<- 'EOF' > /mnt/usr/local/sbin/first-boot-wrapper.sh
#!/usr/bin/env sh

# Run the users script
if [ -f "/usr/local/sbin/first-boot.script" ]
then
  /usr/local/sbin/first-boot.script

  # Clean up the systemctl service
  systemctl disable deb-install-first-boot.service
  rm /etc/systemd/system/deb-install-first-boot.service

  # Clean up by deleting the wrapper script
  rm $0
fi
EOF

    chmod 0754 /mnt/usr/local/sbin/first-boot-wrapper.sh
    chmod 0754 /mnt/usr/local/sbin/first-boot.script
    arch-chroot /mnt systemctl enable deb-install-first-boot.service
  fi
}

### END: Before, After, and First Boot Script Handling

### START: Wrapping Up

clean_up() {
  print_info "Cleaning up"

  # Run updates one last time
  chroot_run_updates

  # Clean apt
  arch-chroot /mnt apt-get clean
  arch-chroot /mnt apt-get autoclean

  # Trim logs
  find /mnt/var/log -type f -cmin +10 -delete
}

stamp_build() {
  print_info "Stamping build"

  # Prepend the /mnt to it and create it if it doesn't exist
  local stamp_path="/mnt${SELECTED_STAMP_LOCATION}"
  mkdir -p "${stamp_path}"

  cp "${LOG}" "${stamp_path}/install-log.log"

  if [[ -f "${OUTPUT_LOG}" ]]; then
    cp "${OUTPUT_LOG}" "${stamp_path}/install-output.log"
  fi

  echo "Build Time: ${INSTALL_DATE}" | tee -a "${stamp_path}/image_build_info"
  echo "Script Version: ${SCRIPT_VERSION}" | tee -a "${stamp_path}/image_build_info"
  echo "Script Date: ${SCRIPT_DATE}" | tee -a "${stamp_path}/image_build_info"
  if [[ "${AUTO_CREATE_USER}" == "1" ]]; then
    user_name="${AUTO_USERNAME}"
    if [[ "${user_name}" == "" ]]; then
      user_name="${AUTO_INSTALL_OS}"
    fi
    echo "Installed User: ${user_name}" | tee -a "${stamp_path}/image_build_info"
  else
    echo "Installed User: (root only)" | tee -a "${stamp_path}/image_build_info"
  fi
}

show_complete_screen() {
  blank_line
  print_line
  print_success "INSTALL COMPLETED"
  print_info "After reboot you can configure users, install other software, etc."
  blank_line
}

### END: Wrapping Up

### START: Script sections

welcome_screen() {
  write_log "In welcome screen."
  print_title
  print_status "Automated script to install Debian and Ubuntu systems the 'Arch Way' (aka deboostrap)."
  blank_line
  print_status "Script version: ${SCRIPT_VERSION} - Script date: ${SCRIPT_DATE}"
  blank_line
  print_status "For more information, documentation, or help:  https://github.com/brennanfee/linux-bootstraps"
  blank_line
  print_line
  blank_line
  print_status "Script can be canceled at any time with CTRL+C"
  blank_line
  if [[ "${AUTO_CONFIRM_SETTINGS}" == "1" || "${IS_DEBUG}" == "1" ]]; then
    pause_output
  fi
}

system_verifications() {
  check_root
  check_linux_distro
  detect_if_eufi
  check_network_connection
}

verify_parameters() {
  print_info "Verifying input parameters..."
  normalize_parameters

  verify_install_os
  verify_install_edition
  verify_kernel_version
  verify_timezone
  verify_user_configuration
  verify_disk_password
  verify_disk_inputs
  verify_config_management

  parse_main_disk
  parse_second_disk
  parse_repo_url
  parse_stamp_path
}

setup_disks() {
  if [[ "${AUTO_SKIP_PARTITIONING}" == "1" ]]; then
    # Just bail, nothing to do
    return
  fi

  unmount_partitions
  wipe_disks
  create_main_partitions
  create_secondary_partitions
  query_disk_partitions

  setup_encryption

  setup_lvm
  format_partitions
  mount_partitions
}

install_main_system() {
  install_base_system
  install_bootloader
}

install_applications() {
  install_applications_debian
  install_applications_ubuntu
  install_applications_common

  install_applications_extra_packages
  install_configuration_management
}

setup_users() {
  setup_root
  setup_data_directory
  setup_service_user
  setup_user
}

do_system_configurations() {
  configure_locale
  configure_keymap
  configure_encryption
  configure_fstab
  configure_hostname
  configure_timezone
  configure_boot
  configure_swap
  configure_networking
  configure_virtualization
}

wrap_up() {
  clean_up
  stamp_build
  show_complete_screen
}

### END: Script sections

### START: The Main Function

do_install() {
  export DEBIAN_FRONTEND=noninteractive
  # Setup local environment
  system_verifications
  install_prereqs
  setup_installer_environment

  # Preamble
  welcome_screen

  run_before_script

  # Parameter Verifications
  verify_parameters
  log_and_confirm

  # Prepare
  get_debootstrap
  setup_clock

  # Setup the core system
  setup_disks
  install_main_system

  # Configurations
  install_applications
  do_system_configurations
  setup_users

  setup_first_boot_script
  run_after_script

  # Finished
  wrap_up
}

main() {
  do_install | tee -a "${OUTPUT_LOG}"

  if [[ "${AUTO_REBOOT}" == "1" ]]; then
    umount -R /mnt || true
    systemctl reboot
  fi
}

### END: The Main Function

main "$@"
