#!/usr/bin/env bash

# Bash strict mode
# shellcheck disable=SC2154
([[ -n ${ZSH_EVAL_CONTEXT} && ${ZSH_EVAL_CONTEXT} =~ :file$ ]] ||
 [[ -n ${BASH_VERSION} ]] && (return 0 2>/dev/null)) && sourced=true || sourced=false
if ! ${sourced}; then
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

# Must be root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root."
  exit 1
fi

in_virtualbox=$(lspci | grep VirtualBox | wc -l)

if [ "${in_virtualbox}" -ge 1 ]; then
  distro=$(lsb_release -i -s | tr '[:upper:]' '[:lower:]')

  if [ "${distro}" = "debian" ]; then
    # Need to ensure the linux headers are installed so it can compile the module
    DEBIAN_FRONTEND=noninteractive apt-get install -y -q --no-install-recommends linux-image-amd64 linux-headers-amd64

    # If a UEFI install, fix the EFI boot
    if [[ -d "/boot/efi/" ]]; then
      if [[ ! -f "/boot/efi/startup.nsh" ]]; then
        echo "FS0:" > /boot/efi/startup.nsh
        echo "\EFI\debian\grubx64.efi" >> /boot/efi/startup.nsh
      fi

      DEBIAN_FRONTEND=noninteractive apt-get install -y -q --no-install-recommends efibootmgr

      if ! efibootmgr | grep -i -q '\* debian'
      then
        efi_device=$(df -P /boot/efi | awk 'END{print $1}')
        efi_disk="/dev/$(lsblk -n -o PKNAME,PATH | grep -i "${efi_device}" | cut -d' ' -f 1)"
        efi_part="$(udevadm info --query=property --name="${efi_device}" | grep -i ID_PART_ENTRY_NUM |cut -d= -f 2)"

        efibootmgr -c -d "${efi_disk}" -p "${efi_part}" -l '\EFI\debian\grubx64.efi' -L 'debian'
      fi
    fi
  fi

  ### Install the guest additions using the ISO

  # NOTE: Why the ISO?  In Debian the guest addition packages are no longer available and while Ubuntu offers them, this provides consistency.  If this script is being used in a packer envrionment, then the guest additions uploaded by it will be used.  If not, the ISO will be downloaded automatically.

  # Can't use $USER as we are running this script as root/sudo
  current_user=$(logname)

  # Determine if we need to download the ISO and do so if needed
  if [ ! -f "/home/${current_user}/VBoxGuestAdditions.iso" ]; then
    # Figure out which version to download
    /usr/bin/wget --output-document "/home/${current_user}/LATEST-STABLE.TXT" https://download.virtualbox.org/virtualbox/LATEST-STABLE.TXT
    vb_version=$(cat "/home/${current_user}/LATEST-STABLE.TXT")
    rm "/home/${current_user}/LATEST-STABLE.TXT"

    # Download it
    vb_url="https://download.virtualbox.org/virtualbox/${vb_version}/VBoxGuestAdditions_${vb_version}.iso"
    /usr/bin/wget --output-document "/home/${current_user}/VBoxGuestAdditions.iso" "${vb_url}"
  fi

  # Mount the ISO and run the install
  mkdir /media/vb-additions
  mount -t iso9660 -o loop,ro /home/"${current_user}"/VBoxGuestAdditions.iso /media/vb-additions
  /media/vb-additions/VBoxLinuxAdditions.run --nox11 || true
  umount /media/vb-additions
  rmdir /media/vb-additions
  rm /home/"${current_user}"/VBoxGuestAdditions.iso

  # Add user to the vboxsf group
  if [ "$(getent group vboxsf | wc -l || true)" -eq 1 ]; then
    usersToAdd=("${current_user}" svcacct ansible vagrant)

    for userToAdd in "${usersToAdd[@]}"
    do
      user_exists=$(getent passwd "${userToAdd}" | wc -l || true)
      if [ "${user_exists}" -eq 1 ]; then
        usermod -a -G vboxsf "${userToAdd}"
      fi
    done
  fi
fi
