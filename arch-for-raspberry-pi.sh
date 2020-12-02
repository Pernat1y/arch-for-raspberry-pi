#!/bin/bash

# Home:
# https://github.com/Pernat1y/arch-for-raspberry-pi/
#
# Docs:
# https://archlinuxarm.org/platforms/armv6/raspberry-pi
# https://archlinuxarm.org/platforms/armv7/broadcom/raspberry-pi-2
# https://archlinuxarm.org/platforms/armv8/broadcom/raspberry-pi-3
# https://archlinuxarm.org/platforms/armv8/broadcom/raspberry-pi-4

rpi_ver=$1
dev=$2
part1=$dev"1"
part2=$dev"2"

# Menu
if [[ -z "$@" || "$@" == "-h"  || "$@" == "--help" ]]; then
    echo ""
    echo "Usage: $0 <rpi_version> <device>"
    echo ""
    echo " <rpi_version>:"
    echo "    1 - Raspberry Pi 1 / Zero / Zero W (ARMv6)"
    echo "    2 - Raspberry Pi 2 / 3             (ARMv7)"
    echo "    3 - Raspberry Pi 3                 (ARMv8)"
    echo "    4 - Raspberry Pi 4                 (ARMv8)"
    echo "    5 - Raspberry Pi 4                 (AArch64)"
    echo ""
    echo " <device> - disk to write image to. Something like /dev/sdX or /dev/mmcblkX"
    echo ""
    exit
fi

# Check for required tools
if ! command -v wget > /dev/null; then
    echo -e "I need those packages to be installed: \nwget bsdtar parted dosfstools \nExiting." && exit
fi

if ! command -v bsdtar > /dev/null; then
    echo -e "I need those packages to be installed: \nwget bsdtar parted dosfstools \nExiting." && exit
fi

if ! command -v parted > /dev/null; then
    echo -e "I need those packages to be installed: \nwget bsdtar parted dosfstools \nExiting." && exit
fi

# Select RPi version
if [[ "$rpi_ver" -eq 1 ]]; then
    rootfs=ArchLinuxARM-rpi-latest.tar.gz
elif [[ "$rpi_ver" -eq 2 ]]; then
    rootfs=ArchLinuxARM-rpi-2-latest.tar.gz
elif [[ "$rpi_ver" -eq 3 ]]; then
    rootfs=ArchLinuxARM-rpi-3-latest.tar.gz
elif [[ "$rpi_ver" -eq 4 ]]; then
    rootfs=ArchLinuxARM-rpi-4-latest.tar.gz
elif [[ "$rpi_ver" -eq 5 ]]; then
    rootfs=ArchLinuxARM-rpi-aarch64-latest.tar.gz
else
    echo "RPi version can be in range 1-5. Exiting." && exit
fi

# Check device file
if [[ ! -b "$dev" ]]; then
    echo "No device selected or not special block file. Exiting." && exit
fi

# Check if device already mounted
if mount | grep -q "$dev"; then
    echo "Device or partition from $dev is already mounted. Exiting." && exit
fi

# Create temp dir
temp_dir=$(mktemp -d)
echo "Entering working dir: $temp_dir"
if ! cd "$temp_dir"; then
    echo "Error while creating temp dir. Exiting." && exit
fi
mkdir boot root 2>/dev/null

if [[ ! -f "$rootfs" ]]; then
    echo "Downloading root FS."
    if ! wget --quiet "http://os.archlinuxarm.org/os/""$rootfs"; then
        echo "Error while downloading FS. Exiting." && exit
    fi
    wget --quiet "http://os.archlinuxarm.org/os/""$rootfs"".md5"
else
    echo "Rootfs already exist. Skipping download."
fi

echo "Checking image hash."
if ! md5sum --check "$rootfs"".md5" ; then
    echo "MD5 checksum failed for image. Exiting." && exit
fi

echo "Creating disk layout."
if ! parted --script "$dev" mklabel msdos; then
    echo "Error while creating disk layout. Exiting." && exit
fi

echo "Creating boot partition on $dev"
if ! parted --script "$dev" mkpart primary fat32 0 100; then
    echo "Error while creating disk layout for boot partition. Exiting." && exit
fi

echo "Setting boot flag on partition."
if ! parted --script "$dev" set 1 boot on; then
    echo "Error while setting boot flag on partition. Exiting." && exit
fi

echo "Creating root partition on $dev "
if ! parted --script "$dev" mkpart primary ext4 100 100%; then
    echo "Error while creating disk layout for root partition. Exiting." && exit
fi

echo "Creating boot file systems."
if ! mkfs.vfat "$part1" >/dev/null; then
    echo "Error while creating boot file system on $part1. Exiting." && exit
fi

echo "Creating root file systems."
if ! mkfs.ext4 "$part2" >/dev/null; then
    echo "Error while creating root file system on $part2. Exiting." && exit
fi

echo "Mounting boot file system."
if ! mount "$part1" boot; then
    echo "Error while mounting $part1. Exiting." && exit
fi

echo "Mounting root file system."
if ! mount "$part2" root; then
    echo "Error while mounting $part2. Exiting." && exit
fi

echo "Unpacking rootfs."
if ! bsdtar -xpf "$rootfs" -C root >/dev/null; then
    echo "Error while unpacking rootfs. Exiting." && exit
fi
sync && mv root/boot/* boot && sync

echo "Unmounting file systems."
if ! umount boot root; then
    echo "Error while unmounting filesystems." && exit
fi

echo "Cleaning up."
cd - && rm -r "$temp_dir"

echo "Done."
