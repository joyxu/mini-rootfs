#!/bin/bash

# Script to auto-build root file system. 
# 
# Author: Fengliang <ChinaFengliang@163.com>
# (C) 2013 Huawei Software Engineering.

export CROSS_COMPILE=aarch64-linux-gnu-
export CC= $(CROSS_COMPILE)gcc
export ARCH=arm64
PATH_CURRENT=$PWD
PATH_ROOTFS=${PWD}/mini-rootfs
PATH_APPLET=${PWD}/applets

# build file system hierarchy
mkdir -p ${PATH_ROOTFS}
pushd ${PATH_ROOTFS}
mkdir -p dev home opt root sys boot etc lib mnt proc run tmp var 
popd

# install applet
for patch in `ls applets`
do
	echo install applet: ${patch} ...
	tar -zxvf ${PATH_APPLET}/${patch} -C ${PATH_ROOTFS}
done

# build busybox
if [ -d busybox ]; then
	echo update busybox
	git pull origin master
else
	echo download busybox
	git clone git://busybox.net/busybox.git
fi

pushd busybox/
make defconfig
make install

PATH_INSTALL=$(grep -i CONFIG_PREFIX .config | cut -d '"' -f 2)
cp -frap ${PATH_INSTALL}/* ${PATH_ROOTFS}
popd

# build dropbear
if [ -d dropbear ]; then
	echo update dropbear
	git pull origin master
else
	echo download dropbear
	git clone https://github.com/mkj/dropbear.git
fi

pushd dropbear/
aclocal
autoheader
autoconf
./configure --prefix=${PATH_ROOTFS} --host=aarch64-linux-gnu --disable-zlib \
	CC=aarch64-linux-gnu-gcc \
	LDFLAGS="-Wl,--gc-sections" \
	CFLAGS="-ffunction-sections -fdata-sections -Os"

make PROGRAMS="dropbear dbclient dropbearkey dropbearconvert scp" strip
make PROGRAMS="dropbear dbclient dropbearkey dropbearconvert scp" install
popd

# build dmidecode

# compress file system
pushd ${PATH_ROOTFS}
find . | cpio -o -H newc | gzip > ../mini-rootfs.cpio.gz
popd

# finished
echo Congratulations, the mini-rootfs.cpio.gz has been created!
