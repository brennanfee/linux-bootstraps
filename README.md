# linux-bootstraps

Repository with shell scripts to bootstrap installations of various Linux distributions.

## Overview

These scripts are various ways to automate much of the installation of various Linux distributions.

The primary purpose for this repo is a set of shell scripts that mimic the "Arch Way" of installing things for both Debian and Ubuntu distributions (and possibly derivatives of those).  Arch is (or will be) supported as well, for those who wish to use that instead.  These "Arch Way" scripts support far more complex and customizable scenarios yet still maintain the ability to be fully automated.  Frankly, I went down this path simply because the default installers provided by the distributions are just not flexible enough or are far too complex, especially in their automated variations.

Also available in this project are pre-seed files for the standard Debian and Ubuntu installers.  However, they are less flexible and are largely intended for virtualized workloads that have fewer demands on partition layouts and various other advanced settings and situations.  For instance, encryption is not supported by the pre-seeds.  However, despite the limitations of the base installers I have supported the ability to customize the installation in various ways as best as I could.

## Warning

Note: **THIS PROJECT IS IN HEAVY DEVELOPMENT AND UNSTABLE, USE AT YOUR OWN RISK!**

The goal of these scripts is NOT to provide a fully baked environment but instead to do the early heavy lifting so that the things that are otherwise difficult to modify after initial installation of Linux are baked in "correctly".  Such as disk partitioning, encryption, UEFI\BIOS configuration, desired kernel and other basics.

**NOTE:** It is fully expected that after initial boot, further (ideally automated) installations and configurations **will be required**.

## Automation

The primary goal of these bootstrap scripts is to support numerous setup scenarios while still being able to be fully automated.  To keep things simpler we don't support EVERY possible variation but instead start from a place of what "should" be most common in the current standards of Linux but offer options for things that truly may be separate desired configurations.

As one example, in no configuration do we support swap partitions because using a swap file is just easier and allows greater flexibility.  However, for the size of swap we do support an option of whether you wish to support hibernation (which requires a much larger swap space than non-hibernation scenarios).

While the scripts work just fine on "bare metal" installations, it is especially excellent with PXE network booting installations as well as with tools like [FAI](https://fai-project.org/) or [Packer](https://www.packer.io/).  In fact, you can view my companion repo [brennanfee/packer-linux](https://github.com/brennanfee/packer-linux) which demonstrates using these scripts within packer to build various machine images.

### Arch-Way Installers

Generally, these scripts expect you to be at a prompt of a live installer (similar to Arch).  Both Debian and Ubuntu provide live server images that provide exactly this.  From there you can set some environment variables to customize the installation, if desired, and then download and run the install script.  The install script will read the environment variables and behave accordingly.  Defaults are provided for every option so if you like your setup exactly like I do you can just run the script straight away without setting any variables.

Please see the readme file in each folder for the given installer to see what parameters are supported and examples of how to customize the installation.

### Pre-seeds

For pre-seeds, the automation is done by passing variables onto the linux boot command (which is generally how you get a pre-seed installations to "go" anyway).  We simply add in some extra values you can pass that will adjust your results.

Please see the readme file in each folder for the given pre-seed on what parameters are supported and examples of how to pass them in.

## Post Install Utility Scripts

Also provided in this repository are some post-install (after initial reboot) scripts for some common configurations.  Admittedly some of them are specific to my needs but others are quite generic.  While it would likely be better that you use either a system configuration tools (such as [Ansible](https://www.ansible.com/), [Chef](https://www.chef.io/), or [Salt](https://saltproject.io/)) or otherwise build custom scripts that build out and configure the system the way you want.

Primarily these scripts are useful for more minimal configurations to round out an image being created, such as through [Packer](https://www.packer.io/).

## License

[MIT](license.md) © 2021 [Brennan Fee](https://github.com/brennanfee)
