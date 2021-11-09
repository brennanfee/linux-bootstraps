#!/usr/bin/env sh

# POSIX strict mode (may produce issues in sourced scenarios)
set -o errexit
set -o nounset
#set -o xtrace # same as set -x, turn on for debugging

IFS=$(printf '\n\t')
# END POSIX scrict mode

# Run updates
in-target DEBIAN_FRONTEND=noninteractive apt-get -y -q update || true
in-target DEBIAN_FRONTEND=noninteractive apt-get -y -q dist-upgrade || true
in-target DEBIAN_FRONTEND=noninteractive apt-get -y -q autoremove || true

# Create a swap file
fallocate -l 4G /target/swapfile
chmod 600 /target/swapfile
mkswap /target/swapfile

# Remove any previous swap
sed -i '/ swap /d' /target/etc/fstab
# Now add the swap file
echo "/swapfile none swap sw 0 0" >> /target/etc/fstab

# Also strip out the cdrom that Debian sometimes includes
sed -i '/^\/dev\/sr0 /d' /target/etc/fstab

# Setup /tmp mounting with tmpfs
cp -v /target/usr/share/systemd/tmp.mount /target/etc/systemd/system/
in-target systemctl enable tmp.mount

# Because we have only one disk we need to create a /data folder as we
# will have no separate volume mounted there.
mkdir -p /target/data

# Copy the install information
if [ -f "/autoinstall-inputs.txt" ]; then
  cp /autoinstall-inputs.txt /target/data/autoinstall-inputs.txt
  chmod +r /target/data/autoinstall-inputs.txt
fi
