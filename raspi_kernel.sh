# on Debian wheezy as root
#
# http://www.nico-maas.de/wordpress/?p=808
# https://mentorlinux.wordpress.com/2013/02/25/raspberry-pi-linux-kernel-cross-compilation/
# http://www.rasplay.org/?p=6371

apt-get -y update && apt-get -y upgrade
apt-get -y install git libncurses5 libncurses5-dev qt4-dev-tools qt4-qmake pkg-config build-essential bc netpbm kpartx pv python zerofree bzip2
#on 64bit os
apt-get -y install libc6-i386 lib32z1 lib32stdc++6

mkdir -p /usr/src/raspi-kernel

# Clone & Download Stuff
#
cd /usr/src/raspi-kernel
wget -O raspbian.zip http://downloads.raspberrypi.org/raspbian_latest && unzip raspbian.zip # (2014-01-07-wheezy)
git clone -- https://github.com/raspberrypi/tools.git
git clone -- https://github.com/raspberrypi/linux.git
git clone -- https://github.com/raspberrypi/firmware.git
git clone -- https://github.com/robopeak/rpusbdisp.git robopeak-rpi-usb-display-mod

# finding the right kernel/firmware git hashes from raspbian release:
# http://www.raspberrypi.org/forums/viewtopic.php?f=66&t=27413#p246670

# integrate robopeak stuff into linux tree
# see robopeak doku: https://github.com/robopeak/rpusbdisp
# or apply this diff/patch on ./linux repo: (created on 15.04.2014)
# https://github.com/piccaso/rpi-linux-kernel/commit/112c4a68634496b42718c5da88659519a6df0eb6
# https://github.com/piccaso/rpi-linux-kernel/commit/112c4a68634496b42718c5da88659519a6df0eb6.diff
# https://github.com/piccaso/rpi-linux-kernel/commit/112c4a68634496b42718c5da88659519a6df0eb6.patch

#logo (optional)
cd /usr/src/raspi-kernel/linux/drivers/video/logo
wget -O logo.jpg https://www.dropbox.com/s/fb0bzhpjwgpdthb/laserbox_logo_white_padding.jpg
jpegtopnm logo.jpg >logo.ppm
ppmquant 224 logo.ppm >logo_224.tmp
pnmnoraw logo_224.tmp > logo_linux_clut224.ppm
cd -

# Make Kernel
export CROSS_COMPILER_PREFIX="/usr/src/raspi-kernel/tools/arm-bcm2708/gcc-linaro-arm-linux-gnueabihf-raspbian/bin/arm-linux-gnueabihf-"

cd /usr/src/raspi-kernel/linux
make mrproper
test -d ../kernel && rm -r ../kernel
mkdir -p ../kernel
# Kernel Types
# find . -name *bcmrpi*config -print
# ./arch/arm/configs/bcmrpi_emergency_defconfig
# ./arch/arm/configs/bcmrpi_defconfig               <-
# ./arch/arm/configs/bcmrpi_cutdown_defconfig
# ./arch/arm/configs/bcmrpi_quick_defconfig
make O=../kernel/ ARCH=arm CROSS_COMPILE=${CROSS_COMPILER_PREFIX} bcmrpi_defconfig

# better pull a config of a raspbian image!!!
# like: wget -O ../kernel/.config https://dl.dropboxusercontent.com/u/129396356/2014-01-07-wheezy-raspbian_kernel.config

make O=../kernel/ ARCH=arm CROSS_COMPILE=${CROSS_COMPILER_PREFIX} menuconfig # xconf

##robopeak display support:
# Select the Displaylink display driver
# ( Device Drivers-> Graphics support -> Support for frame buffer devices-> Displaylink USB Framebuffer support)
# as an external module.
# And Robopeak as module or

##for robopeak and displaylink:
wget -O ../kernel/.config https://dl.dropboxusercontent.com/u/129396356/2014-01-07-wheezy-raspbian_kernel_robopeak_displaylink.config

# -k = keep going, -j2 = 2 async jobs
make O=../kernel/ ARCH=arm CROSS_COMPILE=${CROSS_COMPILER_PREFIX} -k -j2
cd ../tools/mkimage
./imagetool-uncompressed.py ../../kernel/arch/arm/boot/Image

# Kernel Modules
make O=../kernel/ ARCH=arm CROSS_COMPILE=${CROSS_COMPILER_PREFIX} modules
cd ../kernel
test -d ../modules && rm -r ../modules
mkdir -p ../modules/
make modules_install ARCH=arm CROSS_COMPILE=${CROSS_COMPILER_PREFIX} INSTALL_MOD_PATH=../modules/

# Make robopeak kernel module
cd /usr/src/raspi-kernel/robopeak-rpi-usb-display-mod/drivers/linux-driver
## make clean seems broken, so:
git clean -fdx; git reset --hard
make KERNEL_SOURCE_DIR=../../../kernel/ ARCH=arm CROSS_COMPILE=${CROSS_COMPILER_PREFIX}
make modules KERNEL_SOURCE_DIR=../../../kernel/ ARCH=arm CROSS_COMPILE=${CROSS_COMPILER_PREFIX} INSTALL_MOD_PATH=/usr/src/raspi-kernel/modules/
make modules_install KERNEL_SOURCE_DIR=../../../kernel/ ARCH=arm CROSS_COMPILE=${CROSS_COMPILER_PREFIX} INSTALL_MOD_PATH=/usr/src/raspi-kernel/modules/

# Mount target image
cd /usr/src/raspi-kernel
mkdir -p sdb1 sdb2
mv *-wheezy-raspbian.img custom-wheezy-raspbian.img
kpartx -av custom-wheezy-raspbian.img
# /dev names might vary... loop<X>p<N>
mount /dev/mapper/loop0p1 sdb1
mount /dev/mapper/loop0p2 sdb2

# boot partition
cp -va /usr/src/raspi-kernel/firmware/boot/* /usr/src/raspi-kernel/sdb1/
cp -va /usr/src/raspi-kernel/tools/mkimage/kernel.img /usr/src/raspi-kernel/sdb1/kernel.img

# root partition
rm -vr /usr/src/raspi-kernel/sdb2/lib/firmware/
rm -vr /usr/src/raspi-kernel/sdb2/lib/modules/
cp -va /usr/src/raspi-kernel/modules/lib/* /usr/src/raspi-kernel/sdb2/lib/

rm -vr /usr/src/raspi-kernel/sdb2/opt/vc
cp -va /usr/src/raspi-kernel/firmware/hardfp/opt/vc /usr/src/raspi-kernel/sdb2/opt/

cd /usr/src/raspi-kernel

#ext4 options:  defaults,errors=remount-ro,noatime,commit=500
nano sdb2/etc/fstab # and edit...

sync && umount sdb1 && umount sdb2

# ext4 stuff...
# http://askubuntu.com/questions/76913/how-can-i-check-if-a-particular-partition-ext4-is-journaled
# https://wiki.ubuntu.com/MagicFab/SSDchecklist
cd /usr/src/raspi-kernel

# set data=writeback
tune2fs -o journal_data_writeback /dev/mapper/loop0p2

# maybe disable journal?
tune2fs -O ^has_journal /dev/mapper/loop0p2

#optional, zero empty space of root partition (for better compression)
zerofree -v /dev/mapper/loop0p2

# ext4 stuff...
# http://askubuntu.com/questions/76913/how-can-i-check-if-a-particular-partition-ext4-is-journaled
# https://wiki.ubuntu.com/MagicFab/SSDchecklist
# http://askubuntu.com/questions/2194/how-can-i-improve-overall-system-performance

kpartx -dv custom-wheezy-raspbian.img

# compress image
cd /usr/src/raspi-kernel
pv -tpreb custom-wheezy-raspbian.img | bzip2 --best > custom-wheezy-raspbian.img.bzip2

# write image to /dev/sdb (!if this device is the sdcard!)
cd /usr/src/raspi-kernel
pv -tpreb custom-wheezy-raspbian.img | dd bs=16M of=/dev/sdb