#!/bin/bash

# Docs:
# https://archlinuxarm.org/platforms/armv6/raspberry-pi
# https://archlinuxarm.org/platforms/armv7/broadcom/raspberry-pi-2
# https://archlinuxarm.org/platforms/armv8/broadcom/raspberry-pi-3

rpi_ver=$1
dev=$2

if [[ -z "$@" || "$@" == "--help" ]]; then
    echo ""
    echo "Usage:  <version> <device>"
    echo ""
    echo " <version> can be: "
    echo "  1 for Raspberry Pi Zero / Zero W / 1 (ARM v6) "
    echo "  2 for Raspberry Pi 2 / 3 (ARM v7) "
    echo "  3 for Raspberry Pi 3 / 3+ (ARM v8) "
    echo ""
    echo " <device> - disk to write image to. Something like /dev/sdX or /dev/mmcblkX"
    echo ""
    exit
fi

which wget bsdtar parted &>/dev/null
if [[ $? -ne 0 ]]; then
    echo "I need 'wget', 'bsdtar', 'parted' and 'dosfstools' to be installed. Exiting." && exit
fi

if [[ "$rpi_ver" -eq 1 ]]; then
    rootfs=ArchLinuxARM-rpi-latest.tar.gz
elif [[ "$rpi_ver" -eq 2 ]]; then
    rootfs=ArchLinuxARM-rpi-2-latest.tar.gz
elif [[ "$rpi_ver" -eq 3 ]]; then
    rootfs=ArchLinuxARM-rpi-3-latest.tar.gz
else
    echo "RPi version can be in range 1-3. Exiting." && exit
fi

if [[ ! -b "$dev" ]]; then
    echo "No device selected or not special block file. Exiting." && exit
fi

dl_url="http://os.archlinuxarm.org/os/$rootfs"

temp_dir=`mktemp -d`

echo "Entering working dir: $temp_dir"
cd "$temp_dir"
mkdir boot root

echo "Downloading root FS."
wget --quiet "http://os.archlinuxarm.org/os/""$rootfs"
if [[ "$?" -ne "0" ]]; then
    echo "Error while downloading FS. Exiting." && exit
fi

echo "Creating disk layout."
parted --script "$dev" mklabel msdos
if [[ "$?" -ne "0" ]]; then
    echo "Error while creating disk layout. Exiting." && exit
fi

echo "Creating boot partition on $dev"
parted --script "$dev" mkpart primary fat32 0 100
if [[ "$?" -ne "0" ]]; then
    echo "Error while creating disk layout for boot partition. Exiting." && exit
fi

echo "Setting boot flag on partition."
parted --script "$dev" set 1 boot on
if [[ "$?" -ne "0" ]]; then
    echo "Error while setting boot flag on partition. Exiting." && exit
fi

echo "Creating root partition on $dev "
parted --script "$dev" mkpart primary ext4 100 100%
if [[ "$?" -ne "0" ]]; then
    echo "Error while creating disk layout for root partition. Exiting." && exit
fi

echo "Creating boot file systems."
mkfs.vfat "$dev""1"
if [[ "$?" -ne "0" ]]; then
    echo "Error while creating boot file system on "$dev""1" . Exiting." && exit
fi

echo "Creating root file systems."
mkfs.ext4 "$dev""2"
if [[ "$?" -ne "0" ]]; then
    echo "Error while creating root file system on "$dev""2" . Exiting." && exit
fi

echo "Mounting boot file system."
mount "$dev""1" boot
if [[ "$?" -ne "0" ]]; then
    echo "Error while mounting "$dev""1" . Exiting." && exit
fi

echo "Mounting root file system."
mount "$dev""2" root
if [[ "$?" -ne "0" ]]; then
    echo "Error while mounting "$dev""2" . Exiting." && exit
fi

echo "Unpacking rootfs."
bsdtar -xpf "$rootfs" -C root >/dev/null && sync
if [[ "$?" -ne "0" ]]; then
    echo "Error while unpacking rootfs. Exiting." && exit
fi
mv root/boot/* boot && sync

echo "Unmounting file systems."
umount boot root

echo "Done."