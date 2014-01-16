# on Ubuntu 12.04 / Debian wheezy as root
#
# http://www.nico-maas.de/wordpress/?p=808
# https://mentorlinux.wordpress.com/2013/02/25/raspberry-pi-linux-kernel-cross-compilation/
# http://www.rasplay.org/?p=6371

apt-get -y update && apt-get -y upgrade
apt-get -y install git libncurses5 libncurses5-dev qt4-dev-tools qt4-qmake pkg-config build-essential bc netpbm kpartx pv python
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
make O=../kernel/ ARCH=arm CROSS_COMPILE=${CROSS_COMPILER_PREFIX} menuconfig
#xconfig ??
#Device Drivers->
#Input Device Support->
#TouchScreens->USB Touchscreen Driver (Build it into or as module, check if eGalax here!)
#
#. Device Drivers —>
#2. Graphics support —>
#3. [*] Bootup logo —>
#4. — Bootup logo
#[ ] Standard black and white Linux logo
#[ ] Standard 16-color Linux logo
#[*] Standard 224-color Linux logo

# -k = keep going, -j2 = 2 async jobs
make O=../kernel/ ARCH=arm CROSS_COMPILE=${CROSS_COMPILER_PREFIX} -k -j2
cd ../tools/mkimage
./imagetool-uncompressed.py ../../kernel/arch/arm/boot/Image

# Kernel Modules
cd /usr/src/raspi-kernel/kernel
test -d ../modules && rm -r ../modules
mkdir -p ../modules/
make modules_install ARCH=arm CROSS_COMPILE=${CROSS_COMPILER_PREFIX} INSTALL_MOD_PATH=../modules/

# Make robopeak kernel module
cd /usr/src/raspi-kernel/
#RPI_UNAME_R=`ls modules/lib/modules` #quirks...
cd robopeak-rpi-usb-display-mod/drivers/linux-driver
# make clean seems broken, so:
git clean -fdx; git reset --hard
make KERNEL_SOURCE_DIR=../../../kernel/ ARCH=arm CROSS_COMPILE=${CROSS_COMPILER_PREFIX}
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
cp -va /usr/src/raspi-kernel/modules/lib/firmware/ /usr/src/raspi-kernel/sdb2/lib/

rm -vr /usr/src/raspi-kernel/sdb2/lib/modules/
cp -va /usr/src/raspi-kernel/modules/lib/modules/ /usr/src/raspi-kernel/sdb2/lib/

rm -vr /usr/src/raspi-kernel/sdb2/opt/vc
cp -va /usr/src/raspi-kernel/firmware/hardfp/opt/vc/ /usr/src/raspi-kernel/sdb2/opt/

cd /usr/src/raspi-kernel
sync
umount sdb1
umount sdb2
kpartx -dv custom-wheezy-raspbian.img

# write image to /dev/mmcblk0
cd /usr/src/raspi-kernel
pv -tpreb custom-wheezy-raspbian.img | dd of=/dev/mmcblk0 bs=1M