# Debian Scripted Installer

## Overview

The primary purpose for this script is to mimic the "Arch Way" of installing things for both Debian
and Ubuntu distributions (and possibly some day, derivatives of those). These "Arch Way" scripts
support far more complex and customizable scenarios then is possible with cloud-init or pre-seed
environments, yet still maintain the ability to be fully automated. Frankly, I went down this path
simply because the default installers provided by the distributions are just not flexible enough or
are far too complex to work with, especially in their automated variations.

## Standard Installation Method

The standard way of using the script is to boot to a prompt using a "live" server image of either
Debian or Ubuntu and then running a few simple commands. Using live desktop images should work as
well as you can run the necessary commands in a terminal window, however the extra time to load a
full desktop is generally not worth it. It should be noted that no testing is in place for using
live desktop images and so if you run into issues it is recommended to try a live server image first
before filing a bug or seeking other help.

### Boot To Live Linux

The boot media OS does not need to match the desired target OS for the machine being installed. So
you can boot into a Debian ISO to install Debian or Ubuntu, or into an Ubuntu ISO to install either
Debian or Ubuntu. It should not matter.

### Verify Network

Once you are at the command prompt, you need to verify you have an internet connection. This can
best be done by using the "ping" command to reach a common web location like google.com.

```bash
ping -c 3 google.com
```

If you do not have an internet connection you will need to set up the network for the machine you
are on. This documentation cannot go into that detail as each machine and each ISO OS (Debian versus
Ubuntu) may have different ways of initializing the network. Please search for guidance with the
respective Linux distribution documentation and communities.

Only after a network connection has been verified as working can you proceed.

### Export Variables

You now need to export any script variables that are needed to perform the type of installation you
want. This will differ based on your preferences and the machine configuration being installed to.
For a full list of the options available, see the [Description Of Options](#description-of-options)
section below. Be sure to export these variables so they will be correctly read by the script. As an
example:

```bash
export AUTO_HOSTNAME=my-new-machine
export AUTO_USERNAME=bob
```

### Download & Run The Script

After the correct variables have been set you can download and execute the script:

```bash
bash <(curl -fsSL https://tinyurl.com/deb-install)
```

Some prefer to separate the download from the running of the script (as an added security measure,
the script can be examined before executing):

```bash
wget -O deb-install.bash https://tinyurl.com/deb-install
bash ./deb-install.bash
```

## Installation Method With Configuration File

This is the preferred method for doing installations. It allows consistency for multiple machines
that all require the same configuration as well as reduces the steps at the prompt down to two
(verify network and run the config script).

The config scripts are designed to automatically set the export variables needed and then run the
installer script directly. So, no interim steps are necessary.

This can reduce errors as it prevents simple errors like forgetting an AUTO variable, misspelling or
incorrectly setting one of the variables, etc.

### Boot To Prompt

As with the other installation method, you need to boot to a prompt of a "Live" linux distribution.

### Verify Network (As Before)

As with the other installation method, you must verify that you have a working internet connection.
Please see the [Verify Network](#verify-network) section above for more details.

### Download & Run The Configuration Script

One single command is all that is needed to kick things off:

```bash
bash <(curl -fsSL <url to your configuration script>)
```

If desired as two commands; download, then execute:

```bash
wget -O config.bash <url to your configuration script>
bash ./config.bash
```

## Option Data Types

Below lists the different data types and guidelines for their use by the various options read by the
script.

### String Values

For general string values, most often case shouldn't matter. For regular string values I do not
normalize them to lower case or perform any other manipulation on the value passed in. These values
are frequently directly passed in to other Linux commands and so, if case matters, it is due to the
underlying command (such as for time zones).

### Boolean Values

For boolean entries, you may pass in any variant of the following, case insensitive: 'true',
'false', 'T', 'F', 'Y', 'N', 'yes', 'no', '0', '1'. In all cases I normalize the values to the
appropriate boolean value. Any other values will produce an error.

### Item of set

Some string options only allow specific values and you must enter only the values from a set of
acceptable values. For some of these, the set of values may be hard coded or a specific set list of
values within the script (such as AUTO_INSTALL_OS) and for others the values may be dictated by
external components (such as AUTO_INSTALL_EDITION). In all cases, passing in an invalid string
option will produce an appropriate error to inform you the value you passed is not supported.

Items of set are always normalized to lower case, and as such case on input should not matter.

### File Paths and File URLs

Many options allow the passing in of a string representing the location of a file. In all cases you
are free to pass in a full local path (the path must start with a /). Relative paths are generally
not supported. However, instead of a local file you may also pass in a URL. As long as the tool wget
can interpret the URL correctly, the file should be successfully downloaded from the URL provided
and then used. This means you can pass URL's with "http://", "https://", "ftp://", and "file://" as
well as all other schemas supported by wget.

### Passwords

For the users, we offer passing in passwords to use for those accounts. You can pass in a plain text
password or a hashed password. (Note: The disk password does NOT follow this data type and you
should read that variables instructions for it. This data type is only used for user accounts.)

It his highly encouraged to use hashed passwords here so as not to store\show cleartext passwords in
any configuration file, script, or even at the command prompt. To generate a hashed password execute
the following `openssl passwd -6`.

## Description Of Options

All of the configuration items that can be passed to the script begin with "AUTO\_" to indicate
"automatic" or "automating" the script installation.

### AUTO_KEYMAP

Default: 'us' (string)

Supported values: See list of keymaps in Linux

Allows the setting of a key map other than 'us' (the default). This will set the key map on the
target machine. For the interactive script, this setting will also be used as the key map for the
interactive session itself.

### AUTO_LOCALE

Default: 'en_US.UTF-8' (string)

Supported values: See list of locales in Linux

Set the system locale.

### AUTO_TIMEZONE

Default: 'America/Chicago' (string)

Supported values: See list of time zones in Linux

Set the system time zone. This can be particularly important even as part of the install as this
value will be used to set the local clock which can have an effect on evaluating packages and
certificates from the APT repositories.

### AUTO_INSTALL_OS

Default: 'debian' (item of set)

Supported values: 'debian', 'ubuntu'

The OS to install, at present only Debian and Ubuntu are supported.

### AUTO_INSTALL_EDITION

Default: 'stable' (item of set)

Supported values for Debian: Any valid debian branch or codename

Supported values for Ubuntu: 'lts', 'rolling', and any release codename

The edition of the OS to install. Sometimes the edition is called the codename or release. For
debian, names like 'stable' and 'testing' refer to moving release branches while names like
'bullseye' or 'bookworm' refer to specific edition codenames.

For Ubuntu you can use the codename, such as 'jammy' or 'kinetic' as well as two special values of
'lts' and 'rolling' to refer to the latest LTS and latest rolling release, respectively.

**NOTE:** For Ubuntu, there are times when the LTS and rolling releases will resolve to the same
release.

### AUTO_KERNEL_VERSION

Default: 'default' (item of set)

Supported values for Debian: 'default', 'backport', 'backports'

Supported values for Ubuntu: 'default', 'hwe', 'hwe-edge', 'backport', 'backports' (interpreted as
'hwe-edge')

For all distributions "default" will install the default kernel for the edition requested. However,
some distributions support alternate kernels. For those, other values may be supported. For
instance, for Debian stable you can pass "backports" to install the kernel from the backports
repository (if available). For Ubuntu LTS editions you can choose "hwe" and "hwe-edge" as
alternatives.

### AUTO_REPO_OVERRIDE_URL

Default: '' (string)

Allows you to override the repo where the files are pulled from. This is especially useful for
situations where a local Debian or Ubuntu mirror is available. **NOTE:** This will also be the
location the target machine will be pointed at for repository files, so Apt updates will come from
that location rather than the official defaults.

### AUTO_HOSTNAME

Default: '' (string)

The default hostname of the machine being created. If none is passed the hostname will be
autogenerated. The formula used is to use the target OS with a 5 digit random number ('debian-56856'
or 'ubuntu-76319').

### AUTO_DOMAIN

Default: '' (string)

The network domain for the machine being created. This affects the DNS "search domain" when DNS and
machine requests are being evaluated, but is otherwise not needed.

### AUTO_SKIP_PARTITIONING

Default: '0' (boolean value)

Whether to skip automatic partitioning. If not using automatic partition, care must be taken that
the system is properly prepared for system installation. Turning off automatic partition means that
**you are responsible for setting things up correctly**. For this to work as expected, prior to
calling the script (or as part of an AUTO_BEFORE_SCRIPT script) you have partitioned the drives,
formatted the filesystems, and mounted them at or within /mnt ready to be bootstrapped. Furthermore,
you still need to pass in the AUTO_MAIN_DISK value that indicates where you wish Grub to be
installed and initialized (and you have prepared partitions for that as well). With partitioning
turned off you CAN NOT use "smallest" or "largest" for AUTO_MAIN_DISK and must pass in the device
path (like /dev/sda).

This option gives a lot of power to you to control the disk setup as much as you want, but with that
power comes the responsibility of getting it right so the rest of the system installation can
succeed.

### AUTO_MAIN_DISK

Default: 'smallest' (item of list)

Supported values: 'smallest', 'largest', or a device descriptor (such as /dev/sda)

The main disk to install the OS and Grub to. It can be a device (like /dev/sda) or a size match like
"smallest" or "largest". When automatic partitioning, we create a BIOS\UEFI partition, a /boot
partition, and the rest of the disk a / (root) partition. We do not set up a swap partition, but
instead set up a swap file.

### AUTO_SECOND_DISK

Default: 'ignore' (item of list)

Supported values: 'ignore', 'smallest', 'largest', or a device descriptor (such as /dev/sda)

What to do with a second disk on the machine. This setting is ignored if only one disk is found on
the machine. But in cases where two or more disks are found this indicates what should happen. A
value of "ignore", the default, will ignore the second disk and install as though the machine had
only one disk (the main disk). This is the default because it is the safest option. Alternatively,
you can pass a device (like /dev/sdb) which will manually select that as the second disk. Lastly, as
with the main disk, a size selector can be passed like "smallest" or "largest". In the event that
the main disk was selected by the same size selector, this would essentially be the next smallest or
next largest disk, respectively.

At no time can the second disk refer or resolve to the same disk as the main disk. Such situations
will result in an error and the script exiting.

In dual disk automatic partitioning, no change is made to the main disk layout. For the second disk,
this script creates a single LVM volume on the second disk with one of two layouts (based on the
AUTO_USE_DATA_DIR value). Without the data option you get a single LVM partition of 80% for /home
with 20% space free for later LVM expansion\use. With the data directory option you get two
partitions, 50% for /home, 30% for /data, and 20% empty and free for later LVM expansion\use.

### AUTO_ENCRYPT_DISKS

Default: '1' (boolean value)

Whether the volume(s) created should be encrypted. This is a boolean value. The encryption supported
is "whole disk encryption" using LUKS as part of the CryptSetup tools.

### AUTO_DISK_PWD

Default: 'file'

Supported values: 'file' (use an auto-generated file), file path or file URL, any other string to be
used as a password

The password to use for the main encrypted volume. A special value of "file", the default, can be
passed which will generate a disk file in the /boot partition that will auto-decrypt on boot. This
is done so that any automated systems that expect a boot without the need of a human entered
password can still function in a fully automatic way. You can also pass a file to use, the value
entered must follow the File Path or File URL convention described earlier in this documentation.
This file will be copied to the /boot partition to preserve the automatic boot nature required for
automation. Lastly, you can still provide an actual passphrase which will be used. However, this
method will break any automation's as typing the password will be required during boot.

In all configurations, if a second disk is being used a separate file will be generated
automatically as the decryption key for the second disk and stored on the root partition (in the
/etc/keys directory). The system will be configured to automatically unlock that partition after the
root partition is decrypted. This can be considered secure because the root partition must first be
unlocked before the second disk can be accessed.

**NOTE:** This is not intended to be a secure installation without the need for the user to modify
things post bootstrap. This merely "initializes" the encryption as it is much easier to modify the
encryption keys\slots post-installation than it is to encrypt a partition which is already in use
(especially root, which would be impossible). Therefore, it is fully expected that the user will
either replace the file or otherwise manage the encryption keys after initial boot.

**TODO:** Consider adding documentation on manipulating the encryption keys post installation.
Handle common scenarios such as switching to password.

### AUTO_ROOT_DISABLED

Default: '0' (boolean value)

Whether the root account should be disabled. The default is to NOT disable the root account. Some
feel that disabling the root user is a more secure installation footprint, so this setting can be
used for those that wish.

### AUTO_ROOT_PWD

Default: '' (password)

If root is enabled, what the root password should be. If you do not pass a root password, we will
use the same password you passed for the AUTO_USER_PWD. If that is also blank, the password will be
the target installed OS in all lower case ("debian" or "ubuntu", etc.). This can be a plain text
password or a hashed password.

### AUTO_CREATE_USER

Default: '1' (boolean value)

Whether to create a user. If the root user is disabled with the AUTO_ROOT_DISABLED option, this
value will be ignored as in that case a user MUST be created and so we will force the creation of
this user. However, if root is enabled you can optionally turn off the creation of a normal user.

### AUTO_USERNAME

Default: '' (string)

The username to create, if not provided, the default is to create a username that matches the
installed OS (debian or ubuntu).

### AUTO_USER_PWD

Default: '' (password)

The password for the created user. If you do not provide a password the default will be the target
installed OS in all lower case ("debian" or "ubuntu", etc.). The password can be passed as a plain
text password or a hashed password.

### AUTO_USE_DATA_DIR

Default: '0' (boolean value)

Whether to use a /data directory or partition on the target machine. This directory is a personal
convention that I follow and use. Therefore, this option is disabled by default. I use it for all
non-user specific files and setups (usually of docker files, system specific configurations, etc.).
If being used along with the AUTO_SECOND_DISK option, this value does affect the partition scheme
produced. For further details on this read the information under the
[AUTO_SECOND_DISK](#auto_second_disk) option.

Given that this setup is specific to my personal needs it's likely you will always want to leave
this as the default option (off).

### AUTO_STAMP_LOCATION

Default: '' (string)

After installation, the install log and some other files are copied to the target machine. This
option overrides the default location. By default, the files are copied to the `/srv` directory
unless AUTO_USE_DATA_DIR is enabled. With AUTO_USE_DATA_DIR turned on the files are copied to the
/data directory instead of `/srv`. You can override these defaults by providing a path here. Note
that your path MUST start with a full path (must start with /) as relative paths are not supported.

### AUTO_CONFIG_MANAGEMENT

Default: 'none' (item of set)

Supported values: none, ansible, ansible-pip, saltstack, saltstack-repo, saltstack-bootstrap,
puppet, puppet-repo

Install a configuration management system. This can be helpful to have so that on first boot it can
already be installed ready to locally or remotely configure the instance. Default is "none". At
present, each of the systems allows multiple "ways" they might be installed. The first,
non-qualified version always installs the CM tool from the Apt repositories. This should generally
be acceptable but, given the distribution, may be slightly older versions of the CM tools. The other
options perform installations using the CM tools provided methods (pip for Ansible, custom Apt repo
for the others). These should provider newer more updated versions of the CM tools, but might not be
as stable.

At present, bootstrapping Chef is not supported.

### AUTO_EXTRA_PACKAGES

Default: '' (string)

A space separated list of other\extra packages to install to the target machine during the setup.
While it is generally recommended to use a Configuration Management tool such as Ansible, this
option provides a simple way to select a number of packages that should be installed (such as a
desktop environment or some services like print spooling). This string is basically passed directly
to Apt to perform the installation. If you have more advanced needs consider using a script with the
AUTO_AFTER_SCRIPT option or a full Configuration Management system.

### AUTO_EXTRA_PREREQ_PACKAGES

Default: '' (string)

A space separated list of other\extra prerequisite packages to install in the pre-installation
environment. If using an AUTO_BEFORE_SCRIPT or an AUTO_AFTER_SCRIPT, you may have some specific
prerequisite tools that may need to be installed. While in many cases you could install those
packages within the script, the required packages may be needed merely for your script to run (such
as a scripting language, third-party dependencies, etc.). Please be aware that these packages will
not also be installed to the target machine (unless you also use the AUTO_EXTRA_PACKAGES option).

**NOTE:** There is limited virtual disk space in the pre-installation environments so you may not be
able to install all that might be required.

### AUTO_BEFORE_SCRIPT

Default: '' (file path or file URL)

A script to run before the system setup. This runs very early in the installation so it should be
possible for the before script to modify the other AUTO options (exported environment variables) and
therefore effect the rest of the installation process, as needed.

The script itself could be written in any language as long as the script will identify that language
with the correct shebang and that the languages dependencies are available in the pre-installation
environment. Generally Bash and Python are supported out-of-the-box, but if you are using some other
scripting language, you may need to use the AUTO_EXTRA_PREREQ_PACKAGES option to install the
language.

### AUTO_AFTER_SCRIPT

Default: '' (file path or file URL)

A script to run after the system setup but prior to reboot (if AUTO_REBOOT is enabled). At this
stage, the /mnt location should contain the fully installed target system. The after script can
chroot into the /mnt location as needed.

The script itself could be written in any language as long as the script will identify that language
with the correct shebang and that the languages dependencies are available in the pre-installation
environment. Generally Bash and Python are supported out-of-the-box, but if you are using some other
scripting language, you may need to use the AUTO_EXTRA_PREREQ_PACKAGES option to install the
language.

### AUTO_FIRST_BOOT_SCRIPT

Default: '' (file path or file URL)

A script to configure to run once on the target system after initial boot. Note, this script will
run as root, before login of any user, and will ONLY RUN ONCE.

The script itself could be written in any language as long as the script will identify that language
with the correct shebang and that the languages dependencies are available in the target machine
environment. Generally Bash and Python are supported out-of-the-box, but if you are using some other
scripting language, you may need to use the AUTO_EXTRA_PACKAGES option to install the language.

### AUTO_CONFIRM_SETTINGS

Default: '1' (boolean value)

Whether the installer should pause, display the selected and calculated values and wait for
confirmation before continuing. This is done after all the options have been parsed and checked
against the target machine but before any modifications have been made to the target system. On by
default for safety, but should be turned off for fully automated installations.

### AUTO_REBOOT

Default: '0' (boolean value)

Whether to automatically reboot after the script has completed. Default is to not reboot. This gives
the user time to validate things, or perform other installation or configuration tasks manually. At
this point the /mnt location will contain the target system fully installed. The user can manipulate
things as needed, including using chroot with /mnt as the target, and then reboot. For fully
automated installations this should be turned on.

**NOTE**: If not automatically rebooting, it is **highly** encouraged that you properly and safely
unmount the /mnt partition before rebooting. The command to run would be `umount -R /mnt`.
