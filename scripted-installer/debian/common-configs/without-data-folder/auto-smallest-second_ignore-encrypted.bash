#!/usr/bin/env bash
# Author: Brennan Fee
# License: MIT License
#
# Produced by deb-install-interactive.bash.  This is a sourceable file that will export environment variables to be read by the deb-install.bash script.  This allows running a repeatable installation with the same input values.
#
# This configuration uses the main disk "smallest" selection option ignores any secondary disks.  It enables encryption for the main disk.
#
export AUTO_MAIN_DISK=smallest
export AUTO_SECOND_DISK=ignore
export AUTO_ENCRYPT_DISKS=1
export AUTO_USE_DATA_FOLDER=0
