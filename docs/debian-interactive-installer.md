# Debian Interactive Script Installer

## Overview

The interactive script has two purposes:

1. To perform an interactive installation on a target system.  This is to be run from a booted "Live" linux ISO on the target machine where the installation is to be done.  The script will prompt the user for each option and then can perform the installation directly.
2. To generate a "config" script with the users selections from the prompted questions.  This script can then later be used to perform an installation on one or more target systems.  The user can boot a "Live" linux ISO and either manually copy the script (by USB stick or other medium) into the pre-installation environment or download from a web site or network location into the pre-installation environment.

To generate a "config" script it is not necessary to boot into a "Live" linux ISO.  The script can be run on any Linux environment in a terminal.  **NOTE:** Care must be taken when answering the final questions as you want to ensure you select to do a file export and not attempt to perform an installation on the machine you are running on.  You could damage or even wipe your system, losing data, if you accidentally attempt a local installation.

## Interactive Installation Method

This method can be used, rather than calling the regular scripted installation, if you want to be prompted for each option similar to other Linux installations.  The screen prompts give some context on the options but not full documentation, so it is still recommended to read the documentation here in order to fully understand the options and their effects.

### Boot To Live Linux

The boot media OS does not need to match the desired target OS for the machine being installed.  So you can boot into a Debian ISO to install Debian or Ubuntu, or into an Ubuntu ISO to install either Debian or Ubuntu.  It should not matter.

### Verify Network

Once you are at the command prompt, you need to verify you have an internet connection.  This can best be done by using "ping" to reach a common web location like google.com.

`ping -c 3 google.com`

If you do not have an internet connection you will need to set up the network for the machine you are on.  This documentation cannot go into that detail as each machine and each ISO OS (Debian versus Ubuntu) may have different ways of initializing the network.  Please search for guidance with the respective Linux distribution documentation and communities.

Only after a network has been verified as working can you proceed.

### Download & Run The Script

After the correct variables have been set you can download and execute the script:

`bash <(curl -fsSL https://tinyurl.com/interactive-deb-install)`

Some prefer to separate the download from the running of the script (as an added security measure, the script can be examined before executing):

```bash
wget -o installer.bash https://tinyurl.com/interactive-deb-install
bash ./installer.bash
```

### Select Execute At Final Question

Be sure to select "Execute" when asked if you wish to Export a file or Execute the installation.  Once you select "Execute", the installation will confirm that is what you want to do and then immediately start the installation.

## Generating A Config File

To generate a config file which can be used later.  Simply run the interactive script at a local prompt.

`sudo bash ./deb-install-interactive.bash`

At the final question select to "Export" a file and the script will prompt you for a name for your exported file and then produce a script file that can be used at any later time.

## Installation Method With A Config File

For detailed instructions please see the documentation here: [Configuration Installation](docs/debian-scripted-installer.md#installation-method-with-configuration-file)

## Config File Switches

Within the generated config files, there are a number of switches that can be passed to the script upon execution.  They allow the setting of many of the boolean options within the scripted installer.  While the config file still gets final say (by exporting variables), the switches can cut down on the number of permutations of config scripts that might be needed.

For instance, there should be no reason to produce different scripts if all you want to do is direct the installer to not reboot at the end of the installation.  Instead of adding an export variable for AUTO_REBOOT in the config script, you can instead leave the script default and use either -n (short option) or --no-reboot (long option) to tell the script not to reboot.  Alternatively, you can pass -r (short) or --reboot (long) to tell the script to reboot.

Note that these switches, in essence, alter the default values within the installer but the export variables of the config script have the final say, so if AUTO_REBOOT is expressed in the config script, no switches can override that.

### Available Switches

- Automatic Mode (-a, --auto, --auto-mode): Handy single switch to turn on "automatic installation mode".  This value effects the AUTO_CONFIRM_SETTINGS and AUTO_REBOOT settings.
- Confirm Mode (-c, --confirm): Turns on AUTO_CONFIRM_SETTINGS.
- Quiet Mode (-q, --quite, --no-confirm): Turns off AUTO_CONFIRM_SETTINGS.
- Debug Mode (-d, --debug): Turns on the hidden AUTO_IS_DEBUG setting.
- Use Data Mode (--data, --use-data): Turns on the AUTO_USE_DATA_FOLDER setting.
- Do NOT Use Data Mode (--no-data, --no-use-data): Turns off the AUTO_USE_DATA_FOLDER setting.
- Reboot Mode (-r, --reboot): Turns on the AUTO_REBOOT setting.
- Do NOT Reboot Mode (-n, --no-reboot): Turns off the AUTO_REBOOT setting.
- Override Script Source Mode (-s, --script): This option allows you to use a different location to pull the installer script.  This is typically used in debugging and to point to locally edited versions of the script.
- Disks Encrypted Mode (-e, --encrypted): Turns on the AUTO_ENCRYPT_DISKS setting.
- Do NOT Encrypted Disks Mode (-u, --unencrypted | --not-encrypted): Turns off the AUTO_ENCRYPT_DISKS setting.
