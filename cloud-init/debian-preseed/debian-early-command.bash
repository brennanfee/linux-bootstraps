#!/usr/bin/env bash

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
# END Bash scrict mode

main() {
  AUTO_EDITION=$(sed -n 's|^.*AUTO_EDITION=\([^ ]\+\).*$|\1|p' /proc/cmdline)

  AUTO_HOSTNAME=$(sed -n 's|^.*AUTO_HOSTNAME=\([^ ]\+\).*$|\1|p' /proc/cmdline)

  AUTO_DOMAIN=$(sed -n 's|^.*AUTO_DOMAIN=\([^ ]\+\).*$|\1|p' /proc/cmdline)

  AUTO_USERNAME=$(sed -n 's|^.*AUTO_USERNAME=\([^ ]\+\).*$|\1|p' /proc/cmdline)

  AUTO_PASSWORD=$(sed -n 's|^.*AUTO_PASSWORD=\([^ ]\+\).*$|\1|p' /proc/cmdline)

  AUTO_MAIN_DISK=$(sed -n 's|^.*AUTO_MAIN_DISK=\([^ ]\+\).*$|\1|p' /proc/cmdline)

  if [[ -z "${AUTO_HOSTNAME}" ]]; then
    AUTO_HOSTNAME="debian-$((1 + RANDOM % 10000))"
  fi

  {
    echo "CMDLINE=$(cat /proc/cmdline || true)"
    echo "EDITION=${AUTO_EDITION}"
    echo "HOSTNAME=${AUTO_HOSTNAME}"
    echo "DOMAIN=${AUTO_DOMAIN}"
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
  if echo "${AUTO_PASSWORD}" | grep -q '^.*=$'; then
    AUTO_PASSWORD=$(echo "${AUTO_PASSWORD}" | base64 --decode)
    echo "PASSWORD(base64)=${AUTO_PASSWORD}" >> /autoinstall-inputs.txt
  fi

  TMPCONF=$(mktemp)
  cat > "${TMPCONF}" << END_OF_DEBCONF
d-i debconf/priority select critical

END_OF_DEBCONF

  if [[ -n "${AUTO_EDITION}" ]]; then
    {
      echo "d-i mirror/suite select ${AUTO_EDITION}"
      echo "d-i mirror/codename select ${AUTO_EDITION}"
    } >> "${TMPCONF}"
  else
    {
      echo "d-i mirror/suite select stable"
      echo "d-i mirror/codename select stable"
    } >> "${TMPCONF}"
  fi

  if [[ -n "${AUTO_HOSTNAME}" ]]; then
    echo "d-i netcfg/get_hostname string ${AUTO_HOSTNAME}" >> "${TMPCONF}"
    echo "d-i netcfg/hostname string ${AUTO_HOSTNAME}" >> "${TMPCONF}"
  fi

  if [[ -n "${AUTO_DOMAIN}" ]]; then
    echo "d-i netcfg/get_domain string ${AUTO_DOMAIN}" >> "${TMPCONF}"
  fi

  if [[ -n "${AUTO_USERNAME}" ]]; then
    echo "d-i passwd/user-fullname string ${AUTO_USERNAME}" >> "${TMPCONF}"
    echo "d-i passwd/username string ${AUTO_USERNAME}" >> "${TMPCONF}"
  fi

  if [[ -n "${AUTO_PASSWORD}" ]]; then
    # Detect an encrypted password
    if echo "${AUTO_PASSWORD}" | grep -q '^\$[[:digit:]]\$.*$'; then
      {
        echo "d-i passwd/root-password password"
        echo "d-i passwd/root-password-again password"
        echo "d-i passwd/root-password-crypted password ${AUTO_PASSWORD}"

        echo "d-i passwd/user-password password"
        echo "d-i passwd/user-password-again password"
        echo "d-i passwd/user-password-crypted password ${AUTO_PASSWORD}"
      } >> "${TMPCONF}"
    else
      {
        echo "d-i passwd/root-password password ${AUTO_PASSWORD}"
        echo "d-i passwd/root-password-again password ${AUTO_PASSWORD}"
        echo "d-i passwd/root-password-crypted password"

        echo "d-i passwd/user-password password ${AUTO_PASSWORD}"
        echo "d-i passwd/user-password-again password ${AUTO_PASSWORD}"
        echo "d-i passwd/user-password-crypted password"
      } >> "${TMPCONF}"
    fi
  fi

  if [[ -n "${AUTO_MAIN_DISK}" ]]; then
    if [[ "${AUTO_MAIN_DISK}" = "smallest" ]]; then
      # Query the smallest disk
      selected_disk="/dev/$(lsblk --nodeps --noheading --list --include 3,8,22,65,202,253,259 --sort SIZE -o NAME | head -n 1)"
    elif [[ "${AUTO_MAIN_DISK}" = "largest" ]]; then
      # Query the largest disk
      selected_disk="/dev/$(lsblk --nodeps --noheading --list --include 3,8,22,65,202,253,259 --sort SIZE -o NAME | tail -1)"
    else
      selected_disk="${AUTO_MAIN_DISK}"
    fi

    echo "d-i partman-auto/disk string ${selected_disk}" >> "${TMPCONF}"
  fi

  debconf-set-selections "${TMPCONF}"
}

main
