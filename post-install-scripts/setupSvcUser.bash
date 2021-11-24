#!/usr/bin/env bash

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

# Must be root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root."
  exit 1
fi

# Local Services Account
## What is this?  On my systems I like to have a background services user account.  It is not an account that you can log into locally but it can support incoming ssh, can execute scheduled jobs, has a group that others can be added to for access to service files and data, and does not require a password for its use of sudo.

if [ "$(getent passwd svcacct | wc -l || true)" -eq 0 ]; then
  adduser --system --quiet --group --disabled-password --gecos "Services Account" svcacct
fi

# The skel files don't seem to get copied in for "system" users.  Do that manually
[ -f /etc/skel/.bashrc ] && cp /etc/skel/.bashrc /home/svcacct/.bashrc && chown svcacct:svcacct /home/svcacct/.bashrc
[ -f /etc/skel/.profile ] && cp /etc/skel/.profile /home/svcacct/.profile && chown svcacct:svcacct /home/svcacct/.profile
[ -f /etc/skel/.bash_logout ] && cp /etc/skel/.bash_logout /home/svcacct/.bash_logout && chown svcacct:svcacct /home/svcacct/.bash_logout

# Add the ~/.local/bin folder to the path
# shellcheck disable=SC2016
[ -f /home/svcacct/.bashrc ] && echo 'export PATH="$PATH:/home/svcacct/.local/bin"' >> /home/svcacct/.bashrc

# Add the user to some groups
groupsToAdd=(sudo ssh _ssh users data-user vboxsf)

for groupToAdd in "${groupsToAdd[@]}"
do
  group_exists=$(getent group "${groupToAdd}" | wc -l || true)
  if [ "${group_exists}" -eq 1 ]; then
    usermod -a -G "${groupToAdd}" svcacct
  fi
done

cat << EOF > /etc/sudoers.d/svcacct
Defaults:svcacct !requiretty
svcacct ALL=(ALL) NOPASSWD: ALL
EOF

chmod 440 /etc/sudoers.d/svcacct

# Pip
[ ! -f "/tmp/get-pip.py" ] && curl -sSL https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py
runuser --shell=/bin/bash svcacct -c "/usr/bin/python3 /tmp/get-pip.py --user --no-warn-script-location"
