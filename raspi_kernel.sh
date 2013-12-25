# on Ubuntu 12.04 as root
#
# http://www.nico-maas.de/wordpress/?p=808
# https://mentorlinux.wordpress.com/2013/02/25/raspberry-pi-linux-kernel-cross-compilation/
# http://www.rasplay.org/?p=6371

apt-get -y update && apt-get -y upgrade
apt-get -y install git libncurses5 libncurses5-dev qt4-dev-tools qt4-qmake pkg-config build-essential bc netpbm kpartx # gcc-arm-linux-gnueabi
mkdir -p ~/rpi_kernel

# Clone & Download Stuff

cd ~/rpi_kernel
wget -O raspbian.zip http://downloads.raspberrypi.org/raspbian_latest
git clone https://github.com/raspberrypi/tools.git
git clone https://github.com/raspberrypi/linux.git
git clone https://github.com/raspberrypi/firmware.git

#nah...
cd ~/rpi_kernel/linux/.git
git branch -a
cd ~/rpi_kernel/linux
git checkout -t -b remotes/origin/rpi-3.10.y # sure?
git pull
cd ~/rpi_kernel/firmware/.git
git branch -a
cd ~/rpi_kernel/firmware
git checkout -t -b next remotes/origin/next # sure?
git pull
#/nah...

#logo
cd ~/rpi_kernel/linux/drivers/video/logo
wget -O logo.jpg https://www.dropbox.com/s/fb0bzhpjwgpdthb/laserbox_logo_white_padding.jpg
jpegtopnm logo.jpg >logo.ppm
ppmquant 224 logo.ppm >logo_224.tmp
pnmnoraw logo_224.tmp > logo_linux_clut224.ppm

# Make Kernel
export CROSS_COMPILER_PREFIX="~/rpi_kernel/tools/arm-bcm2708/gcc-linaro-arm-linux-gnueabihf-raspbian/bin/arm-linux-gnueabihf-"
export CROSS_COMPILER_PREFIX="~/rpi_kernel/tools/arm-bcm2708/arm-bcm2708-linux-gnueabi/bin/arm-bcm2708-linux-gnueabi-"
cd ~/rpi_kernel/linux
make mrproper
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
make O=../kernel/ ARCH=arm CROSS_COMPILE=${CROSS_COMPILER_PREFIX} -k -j3 #coffee time
cd ../tools/mkimage
./imagetool-uncompressed.py ../../kernel/arch/arm/boot/Image
cd ../../

# Make Modules
cd ~/rpi_kernel/kernel
mkdir -p ../modules/
make modules_install ARCH=arm CROSS_COMPILE=${CROSS_COMPILER_PREFIX} INSTALL_MOD_PATH=../modules/


# Mount target image
cd ~/rpi_kernel
mkdir -p sdb1 sdb2
unzip raspbian.zip
mv *-wheezy-raspbian.img custom-wheezy-raspbian.img
kpartx -av custom-wheezy-raspbian.img
mount /dev/mapper/loop0p1 sdb1
mount /dev/mapper/loop0p2 sdb2

# boot partition
cp ~/rpi_kernel/firmware/boot/* ~/rpi_kernel/sdb1/
cp ~/rpi_kernel/tools/mkimage/kernel.img ~/rpi_kernel/sdb1/kernel.img

# root partition
rm -r ~/rpi_kernel/sdb2/lib/firmware/
cp -a ~/rpi_kernel/modules/lib/firmware/ ~/rpi_kernel/sdb2/lib/

rm -r ~/rpi_kernel/sdb2/lib/modules/
cp -a ~/rpi_kernel/modules/lib/modules/ ~/rpi_kernel/sdb2/lib/

rm -r ~/rpi_kernel/sdb2/opt/vc
cp -a ~/rpi_kernel/firmware/hardfp/opt/vc/ ~/rpi_kernel/sdb2/opt/

cd ~/rpi_kernel
sync
umount sdb1
umount sdb2
kpartx -dv custom-wheezy-raspbian.img