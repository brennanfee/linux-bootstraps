#!/usr/bin/env sh

# POSIX strict mode (may produce issues in sourced scenarios)
set -o errexit
set -o nounset
#set -o xtrace # same as set -x, turn on for debugging

IFS=$(printf '\n\t')
# END POSIX scrict mode

# Start with disabling ssh
systemctl stop ssh

# Read the values from the linux kernel command.

AUTO_HOSTNAME=$(sed -n 's|^.*AUTO_HOSTNAME=\([^ ]\+\).*$|\1|p' /proc/cmdline)

AUTO_USERNAME=$(sed -n 's|^.*AUTO_USERNAME=\([^ ]\+\).*$|\1|p' /proc/cmdline)

AUTO_PASSWORD=$(sed -n 's|^.*AUTO_PASSWORD=\([^ ]\+\).*$|\1|p' /proc/cmdline)

AUTO_MAIN_DISK=$(sed -n 's|^.*AUTO_MAIN_DISK=\([^ ]\+\).*$|\1|p' /proc/cmdline)

{
  echo "CMDLINE=$(cat /proc/cmdline)"
  echo "HOSTNAME=${AUTO_HOSTNAME}"
  echo "USERNAME=${AUTO_USERNAME}"
  echo "PASSWORD=${AUTO_PASSWORD}"
  echo "MAIN_DISK=${AUTO_MAIN_DISK}"
} > /autoinstall-inputs.txt

# NOTE: AUTO_PASSWORD supports both unencrypted and encrypted passwords.
# However, encrypted passwords need to be passed on the Linux boot command
# line in base64 to avoid conflicts.  We detect a base64 string by the
# closing equal symbol '=' that is at the end of all base64 strings.
# We also detect crypted passwords with the dollar symbol, digit, dollar symbol
# pattern ('$[[:digit:]]$') that is at the front of all crypted passwords.

# If it is base64 encoded, decode it
if echo "${AUTO_PASSWORD}" | grep -q '^.*=$'
then
  AUTO_PASSWORD=$(echo "${AUTO_PASSWORD}" | base64 --decode)
  echo "PASSWORD(base64)=${AUTO_PASSWORD}" >> /autoinstall-inputs.txt
fi

# If it is not encrypted, encrypt it
if ! echo "${AUTO_PASSWORD}" | grep -q '^\$[[:digit:]]\$.*$'
then
  AUTO_PASSWORD=$(echo "${AUTO_PASSWORD}" | openssl passwd -6 -stdin)
  echo "PASSWORD(encrypted)=${AUTO_PASSWORD}" >> /autoinstall-inputs.txt
fi

# Throw it away to ensure we can boot - debugging, the password is 'test'
# shellcheck disable=SC2016
#AUTO_PASSWORD='$6$dBGHy9x3f7Ps8sqX$E4tLFh5LiGciwUoA4eLB1hMNTD84A2a3uejsm8jEsrVqob.pPgab1oRJdFFdPYYnSp7Qm0577PWKXooKCVDmM/'

# Use the values

if [ -n "${AUTO_HOSTNAME}" ]; then
  sed -i -r "/hostname:/ s|:.*$|: ${AUTO_HOSTNAME}|" /autoinstall.yaml
fi

if [ -n "${AUTO_USERNAME}" ]; then
  sed -i -r "/username:/ s|:.*$|: ${AUTO_USERNAME}|" /autoinstall.yaml
fi

if [ -n "${AUTO_PASSWORD}" ]; then
  sed -i -r "/password:/ s|:.*$|: ${AUTO_PASSWORD}|" /autoinstall.yaml
fi

if [ -n "${AUTO_MAIN_DISK}" ]; then
  if [ "${AUTO_MAIN_DISK}" = "smallest" ]; then
    # Replace the "size" designator
    sed -i -r "s|size: smallest$|size: ${AUTO_MAIN_DISK}|" /autoinstall.yaml
  elif [ "${AUTO_MAIN_DISK}" = "largest" ]; then
    # Replace the "size" designator
    sed -i -r "s|size: smallest$|size: ${AUTO_MAIN_DISK}|" /autoinstall.yaml
  else
    # Assume they passed a device (/dev/sda) and replace the whole match
    sed -i -r "/match:/ s|match:.*$|path: ${AUTO_MAIN_DISK}|" /autoinstall.yaml
    sed -i -r "/size: smallest$/d" /autoinstall.yaml
  fi
fi
