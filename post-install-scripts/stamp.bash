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

echo "Build Time: $(date -Is)" | sudo tee /data/image_build_info

set +o nounset
if [ -n "${PACKER_BUILD_NAME}" ]; then
  echo "Packer Build Name: ${PACKER_BUILD_NAME}" | sudo tee -a /data/image_build_info
fi

if [ -n "${PACKER_BUILDER_TYPE}" ]; then
  echo "Packer Builder Type: ${PACKER_BUILDER_TYPE}" | sudo tee -a /data/image_build_info
fi
set -o nounset

# Can't use $USER here because we are running this script as root
current_user=$(logname)
echo "Installed User: ${current_user}" | sudo tee -a /data/image_build_info

if [ -f /home/"${current_user}"/.vbox_version ]; then
  vbox_version=$(cat /home/"${current_user}"/.vbox_version)
  echo "VirtualBox Version: ${vbox_version}" | sudo tee -a /data/image_build_info
  rm /home/"${current_user}"/.vbox_version
fi

chown root:data-user /data/image_build_info
chmod g+w /data/image_build_info
