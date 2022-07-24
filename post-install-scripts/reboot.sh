#!/usr/bin/env sh

# POSIX strict mode (may produce issues in sourced scenarios)
set -o errexit
set -o nounset
#set -o xtrace # same as set -x, turn on for debugging

IFS=$(printf '\n\t')
# END POSIX scrict mode

# Must be root
cur_user=$(id -u)
if [ ${cur_user} -ne 0 ]
then
  echo "This script must be run as root."
  exit 1
fi
unset cur_user

## Reboot
systemctl reboot
