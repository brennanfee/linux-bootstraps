#!/usr/bin/env bash

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

# Must be root
cur_user=$(id -u)
if [[ ${cur_user} -ne 0 ]]
then
  echo "This script must be run as root."
  exit 1
fi
unset cur_user

if [[ "$(getent passwd vagrant | wc -l || true)" -eq 1 ]]
then
  echo 'Setting up vagrant user'

  # Install vagrant ssh key
  if [[ ! -f /home/vagrant/.ssh/authorized_keys ]]
  then
    mkdir -p /home/vagrant/.ssh
    wget -nv --no-check-certificate -O /home/vagrant/.ssh/authorized_keys 'https://raw.githubusercontent.com/hashicorp/vagrant/master/keys/vagrant.pub'
    chown -R vagrant /home/vagrant/.ssh
    chmod -R go-rwsx /home/vagrant/.ssh
  fi

  # Add vagrant user to passwordless sudo
  if [[ ! -f /etc/sudoers.d/vagrant ]]
  then
    cat << EOF > /etc/sudoers.d/vagrant
Defaults:svcacct !requiretty
svcacct ALL=(ALL) NOPASSWD: ALL
EOF

    chmod 440 /etc/sudoers.d/vagrant
  fi

  # Add the user to some groups
  groupsToAdd=(sudo ssh _ssh users data-user vboxsf)

  for groupToAdd in "${groupsToAdd[@]}"
  do
    group_exists=$(getent group "${groupToAdd}" | wc -l || true)
    if [[ "${group_exists}" -eq 1 ]]
    then
      usermod -a -G "${groupToAdd}" vagrant
    fi
  done
fi
