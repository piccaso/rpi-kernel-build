#!/bin/bash

{
  export FIRMWARE_COMMIT=master
  #--
  export REPO_WORKDIR=$(pwd)
  mkdir -p /tmp/rpi-kernel-$RANDOM && cd $_
  export RPI_KERNEL_WORKDIR=$(pwd)
  export LOG_DIR=$RPI_KERNEL_WORKDIR/build/var/log/rpi-kernel-build
  rm -rf build
  mkdir -p $LOG_DIR
  export DEBIAN_FRONTEND=noninteractive
  apt-get -yq update
  apt-get -yq install git libncurses5 libncurses5-dev qt4-dev-tools qt4-qmake pkg-config build-essential bc netpbm kpartx pv python zerofree bzip2 libc6-i386 lib32z1 lib32stdc++6
  wget -O robopeak.patch https://github.com/piccaso/rpi-linux-kernel/commit/d24310372556f4cc64e119f18f36b504c8c16093.patch
  export ROBOPEAK_COMMIT=$(grep 'robopeak/rpusbdisp/commit/.*' robopeak.patch | grep -oP '[0-9a-f]{40}')

  #-- tools/robopeak dl job (background)
  {
    wget https://github.com/raspberrypi/tools/archive/master.tar.gz -O tools.tar.gz && tar -zxvf $_ && mv tools-* tools
    wget https://github.com/robopeak/rpusbdisp/archive/${ROBOPEAK_COMMIT}.tar.gz -O robopeak-rpi-usb-display-mod.tar.gz && tar -zxvf $_ && mv rpusbdisp-* robopeak-rpi-usb-display-mod
  } 2>&1 | pv -tbi 10 -N tools-download > $LOG_DIR/tools-download.log &

  #-- kernel dl job
  {
    wget https://github.com/raspberrypi/firmware/archive/${FIRMWARE_COMMIT}.tar.gz -O firmware.tar.gz && tar -zxvf $_&& mv firmware-* firmware
    export LINUX_COMMIT=$(cat firmware/extra/git_hash)
    wget https://github.com/raspberrypi/linux/archive/${LINUX_COMMIT}.tar.gz -O linux.tar.gz && tar -zxvf $_ && mv linux-* linux
    wget -O robopeak.patch https://github.com/piccaso/rpi-linux-kernel/commit/d24310372556f4cc64e119f18f36b504c8c16093.patch
    patch -p1 -d linux --verbose --batch -i ../robopeak.patch
  } 2>&1 | pv -tbi 10 -N kernel-download > $LOG_DIR/kernel-download.log

  wait

  {
    export CROSS_COMPILER_PREFIX="$RPI_KERNEL_WORKDIR/tools/arm-bcm2708/gcc-linaro-arm-linux-gnueabihf-raspbian/bin/arm-linux-gnueabihf-"
    cd $RPI_KERNEL_WORKDIR/linux
    # make mrproper
    # test -d ../kernel && rm -r ../kernel
    mkdir -p ../kernel
    make O=../kernel/ ARCH=arm CROSS_COMPILE=${CROSS_COMPILER_PREFIX} bcmrpi_defconfig
    #--------old# wget -O ../kernel/.config https://dl.dropboxusercontent.com/u/129396356/2014-01-07-wheezy-raspbian_kernel.config
    #--------new# wget -O ../kernel/.config https://dl.dropboxusercontent.com/u/5317838/neno/2014-09-17-kernel.config-mogi-rpi-3.12.28.config
    #interactive# make O=../kernel/ ARCH=arm CROSS_COMPILE=${CROSS_COMPILER_PREFIX} menuconfig

    # may work....
    cp -vf $REPO_WORKDIR/.config ../kernel/.config

    make O=../kernel/ ARCH=arm CROSS_COMPILE=${CROSS_COMPILER_PREFIX} -k -j2

    cd ../tools/mkimage
    ./imagetool-uncompressed.py ../../kernel/arch/arm/boot/Image

    cd $RPI_KERNEL_WORKDIR/linux
    make O=../kernel/ ARCH=arm CROSS_COMPILE=${CROSS_COMPILER_PREFIX} modules
      # --*
    cd ../kernel
    # test -d ../modules && rm -r ../modules
    mkdir -p ../modules/
    make modules_install ARCH=arm CROSS_COMPILE=${CROSS_COMPILER_PREFIX} INSTALL_MOD_PATH=../modules/

    cd $RPI_KERNEL_WORKDIR/robopeak-rpi-usb-display-mod/drivers/linux-driver
    # where is make clean?

    make KERNEL_SOURCE_DIR=../../../kernel/ ARCH=arm CROSS_COMPILE=${CROSS_COMPILER_PREFIX}
    make modules KERNEL_SOURCE_DIR=../../../kernel/ ARCH=arm CROSS_COMPILE=${CROSS_COMPILER_PREFIX} INSTALL_MOD_PATH=../../../modules
    make modules_install KERNEL_SOURCE_DIR=../../../kernel/ ARCH=arm CROSS_COMPILE=${CROSS_COMPILER_PREFIX} INSTALL_MOD_PATH=../../../modules

    cd $RPI_KERNEL_WORKDIR
    mkdir -p build/boot
    mkdir -p build/lib
    mkdir -p build/opt

    # boot partition
    cp -va $RPI_KERNEL_WORKDIR/firmware/boot/* $RPI_KERNEL_WORKDIR/build/boot/
    cp -va $RPI_KERNEL_WORKDIR/tools/mkimage/kernel.img $RPI_KERNEL_WORKDIR/build/boot/kernel.img

    # root partition
    cp -va $RPI_KERNEL_WORKDIR/modules/lib/* $RPI_KERNEL_WORKDIR/build/lib/
    cp -va $RPI_KERNEL_WORKDIR/firmware/hardfp/opt/vc $RPI_KERNEL_WORKDIR/build/opt/
  } 2>&1 | pv -tbi 10 -N kernel-bulid > $LOG_DIR/kernel-bulid.log
  cd build && tar -zcf ../build.tar.gz . ; cd $RPI_KERNEL_WORKDIR

}
