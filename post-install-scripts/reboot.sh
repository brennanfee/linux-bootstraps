#!/usr/bin/env sh

# POSIX strict mode (may produce issues in sourced scenarios)
set -o errexit
set -o nounset
#set -o xtrace # same as set -x, turn on for debugging

IFS=$(printf '\n\t')
# END POSIX scrict mode

# Must be root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root."
  exit 1
fi

## Reboot
systemctl reboot
