# on Ubuntu 12.04 as root
#
# http://www.nico-maas.de/wordpress/?p=808
# https://mentorlinux.wordpress.com/2013/02/25/raspberry-pi-linux-kernel-cross-compilation/
# http://www.rasplay.org/?p=6371

apt-get -y update && apt-get -y upgrade
apt-get -y install git libncurses5 libncurses5-dev qt4-dev-tools qt4-qmake pkg-config build-essential gcc-arm-linux-gnueabi bc netpbm



# Clone Stuff
mkdir ~/rpi_kernel_10
cd ~/rpi_kernel_10
git clone https://github.com/raspberrypi/tools.git #coffee time
git clone https://github.com/raspberrypi/linux.git #coffee time
cd ~/rpi_kernel_10/linux/.git
git branch -a
cd ~/rpi_kernel_10/linux
git checkout -t -b remotes/origin/rpi-3.10.y
git pull
cd ~/rpi_kernel_10
git clone https://github.com/raspberrypi/firmware.git #coffee time
cd ~/rpi_kernel_10/firmware/.git
git branch -a
cd ~/rpi_kernel_10/firmware
git checkout -t -b next remotes/origin/next
git pull

#logo
cd ~/rpi_kernel_10/linux/drivers/video/logo
wget -O logo.jpg https://www.dropbox.com/s/fb0bzhpjwgpdthb/laserbox_logo_white_padding.jpg
jpegtopnm logo.jpg >logo.ppm
ppmquant 224 logo.ppm >logo_224.tmp
pnmnoraw logo_224.tmp > logo_linux_clut224.ppm

# Make Kernel
cd ~/rpi_kernel_10/linux
make mrproper
mkdir -p ../kernel
# Kernel Types
# find . -name *bcmrpi*config -print
# ./arch/arm/configs/bcmrpi_emergency_defconfig
# ./arch/arm/configs/bcmrpi_defconfig               <-
# ./arch/arm/configs/bcmrpi_cutdown_defconfig
# ./arch/arm/configs/bcmrpi_quick_defconfig
make O=../kernel/ ARCH=arm CROSS_COMPILE=/usr/bin/arm-linux-gnueabi- bcmrpi_defconfig
make O=../kernel/ ARCH=arm CROSS_COMPILE=/usr/bin/arm-linux-gnueabi- menuconfig
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
make O=../kernel/ ARCH=arm CROSS_COMPILE=/usr/bin/arm-linux-gnueabi- -k -j3 #coffee time
cd ../tools/mkimage
./imagetool-uncompressed.py ../../kernel/arch/arm/boot/Image
cd ../../

# Make Modules
cd ~/rpi_kernel_10/kernel
mkdir -p ../modules/

# prepare for transfer
cd ~
mkdir sdb1 sdb2

# boot partition
#replace /sdb1/boot/bootcode.bin with rpi_kernel_10/firmware/boot/bootcode.bin
rm ~/sdb1/bootcode.bin
cp ~/rpi_kernel_10/firmware/boot/bootcode.bin ~/sdb1/
#replace /sdb1/boot/kernel.img with the previously created kernel image
rm ~/sdb1/kernel.img
cp ~/rpi_kernel_10/tools/mkimage/kernel.img ~/sdb1/
#replace /sdb1/boot/start.elf with rpi_kernel_10/firmware/boot/start.elf
rm ~/sdb1/start.elf
cp ~/rpi_kernel_10/firmware/boot/start.elf ~/sdb1/

# root partition
#replace /sdb2/lib/firmware with <modules_builded_above_folder>/lib/firmware
mkdir -p ~/sdb2/lib/firmware
mkdir -p ~/sdb2/lib/modules
mkdir -p ~/sdb2/opt/vc

rm -rf ~/sdb2/lib/firmware/
cp -a ~/rpi_kernel_10/modules/lib/firmware/ ~/sdb2/lib/
#replace /sdb2/lib/modules with <modules_builded_above_folder>/lib/modules
rm -rf ~/sdb2/lib/modules/
cp -a ~/rpi_kernel_10/modules/lib/modules/ ~/sdb2/lib/
#replace /sdb2/opt/vc with firmware-next/hardfp/opt/vc/
rm -rf ~/sdb2/opt/vc
cp -a ~/rpi_kernel_10/firmware/hardfp/opt/vc/ ~/sdb2/opt/

cd ~
tar -zcvf newkernel.tgz sdb1 sdb2
























