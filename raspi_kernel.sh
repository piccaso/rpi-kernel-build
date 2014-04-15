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
wget -O raspbian.zip http://downloads.raspberrypi.org/raspbian_latest && unzip raspbian.zip
git clone -- https://github.com/raspberrypi/tools.git
git clone -- https://github.com/raspberrypi/linux.git
git clone -- https://github.com/raspberrypi/firmware.git
git clone -- https://github.com/robopeak/rpusbdisp.git robopeak-rpi-usb-display-mod

#nah...
#cd /usr/src/raspi-kernel/linux/.git
#git branch -a
#cd /usr/src/raspi-kernel/linux
#git checkout -t -b remotes/origin/rpi-3.10.y # sure?
#git pull
#cd /usr/src/raspi-kernel/firmware/.git
#git branch -a
#cd /usr/src/raspi-kernel/firmware
#git checkout -t -b next remotes/origin/next # sure?
#git pull
#/nah...

#logo
cd /usr/src/raspi-kernel/linux/drivers/video/logo
wget -O logo.jpg https://www.dropbox.com/s/fb0bzhpjwgpdthb/laserbox_logo_white_padding.jpg
jpegtopnm logo.jpg >logo.ppm
ppmquant 224 logo.ppm >logo_224.tmp
pnmnoraw logo_224.tmp > logo_linux_clut224.ppm

# Make Kernel
export CROSS_COMPILER_PREFIX="/usr/src/raspi-kernel/tools/arm-bcm2708/gcc-linaro-arm-linux-gnueabihf-raspbian/bin/arm-linux-gnueabihf-"
#export CROSS_COMPILER_PREFIX="/usr/src/raspi-kernel/tools/arm-bcm2708/arm-bcm2708-linux-gnueabi/bin/arm-bcm2708-linux-gnueabi-"
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
cd /usr/src/raspi-kernel/kernel
test -d ../modules && rm -r ../modules
mkdir -p ../modules/
make modules_install ARCH=arm CROSS_COMPILE=${CROSS_COMPILER_PREFIX} INSTALL_MOD_PATH=../modules/

### no longer needed??
#
## Make robopeak kernel module
#cd /usr/src/raspi-kernel/
##RPI_UNAME_R=`ls modules/lib/modules` #quirks...
#cd robopeak-rpi-usb-display-mod/drivers/linux-driver
## make clean seems broken, so:
#git clean -fdx; git reset --hard
#make KERNEL_SOURCE_DIR=../../../kernel/ ARCH=arm CROSS_COMPILE=${CROSS_COMPILER_PREFIX}
#make modules_install KERNEL_SOURCE_DIR=../../../kernel/ ARCH=arm CROSS_COMPILE=${CROSS_COMPILER_PREFIX} INSTALL_MOD_PATH=/usr/src/raspi-kernel/modules/
#
### ??

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
sync
umount sdb1
umount sdb2

#optional, zero empty space of root partition (for better compression)
zerofree -v /dev/mapper/loop0p2

#maybe remove journal?
#http://askubuntu.com/questions/76913/how-can-i-check-if-a-particular-partition-ext4-is-journaled
#https://wiki.ubuntu.com/MagicFab/SSDchecklist

kpartx -dv custom-wheezy-raspbian.img

# compress image
cd /usr/src/raspi-kernel
pv -tpreb custom-wheezy-raspbian.img | bzip2 --best > custom-wheezy-raspbian.img.bzip2

# write image to /dev/sdb (!if this device is the sdcard!)
cd /usr/src/raspi-kernel
pv -tpreb custom-wheezy-raspbian.img | dd of=/dev/sdb bs=1M