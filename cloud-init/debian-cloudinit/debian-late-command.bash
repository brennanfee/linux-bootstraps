#!/usr/bin/env bash

# Bash strict mode
([[ -n ${ZSH_EVAL_CONTEXT:-} && ${ZSH_EVAL_CONTEXT:-} =~ :file$ ]] ||
  [[ -n ${BASH_VERSION:-} ]] && (return 0 2>/dev/null)) && SOURCED=true || SOURCED=false
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

# Run updates
curtin in-target --target=/target -- DEBIAN_FRONTEND=noninteractive apt-get -y -q update || true
curtin in-target --target=/target -- DEBIAN_FRONTEND=noninteractive apt-get -y -q dist-upgrade || true
curtin in-target --target=/target -- DEBIAN_FRONTEND=noninteractive apt-get -y -q autoremove || true

# Create a swap file
fallocate -l 4G /target/swapfile
chmod 600 /target/swapfile
mkswap /target/swapfile

# Remove any previous swap
sed -i '/ swap /d' /target/etc/fstab
# Now add the swap file
echo "/swapfile none swap sw 0 0" >>/target/etc/fstab

# Setup /tmp mounting with tmpfs
cp -v /target/usr/share/systemd/tmp.mount /target/etc/systemd/system/
curtin in-target --target=/target -- systemctl enable tmp.mount

# Because we have only one disk we need to create a /data directory as we
# will have no separate volume mounted there.
mkdir -p /target/data

# Copy the final autoinstall script
cp /autoinstall.yaml /target/data/autoinstall.yaml
chmod +r /target/data/autoinstall.yaml

if [[ -f "/autoinstall-inputs.txt" ]]; then
  cp /autoinstall-inputs.txt /target/data/autoinstall-inputs.txt
  chmod +r /target/data/autoinstall-inputs.txt
fi
