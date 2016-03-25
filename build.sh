#!/bin/bash

# Script to auto-build root file system. 
# 
# Author: Fengliang <ChinaFengliang@163.com>
# (C) 2013 Huawei Software Engineering.

version="0.2.1"

usage="Auto-build a mini root file system for target machine.
Usage: $0 [OPTION | SETTING]

OPTION:
-h, --help         print this help, then exit
-v, --version      print version number and configuration settings, then exit
-c, --clean        clean the working tree

SETTING:
ARCH=              set architecture of processor
CROSS_COMPILE=     set cross-compile tools

Report bugs to <ChinaFengliang@163.com>."
																							 
while test $# != 0
do
	case $1 in
		CROSS_COMPILE=*)
			CROSS_COMPILE=`expr "X$1" : 'X[^=]*=\(.*\)'`
			;;
		ARCH=*)
			ARCH=`expr "X$1" : 'X[^=]*=\(.*\)'`
			;;
		-c | --clean)
			git clean -dxf
			exit
			;;
		-h | --help)
			echo "$usage"
			exit
			;;
		-v | --version)
			echo "$version"
			exit
			;;
		*)
			echo "ERROR: not support $1"
			exit
			;;
	esac
	shift
done

# When the ARCH is not specified, arm64 will be used as the default arch 
if [ x"" = x"$ARCH" ]; then
	ARCH=arm64
fi

if [ x"arm64" != x"$ARCH" -a x"aarch64" != x"$ARCH" -a x"arm" != x"$ARCH"  -a x"arm32" != x"$ARCH" ]; then
	echo "ERROR: unknown ARCH=$ARCH is specified!"
	exit
fi

# When the CROSS_COMPILE is not specified, we guess default CROSS_COMPILE according to arch setting
if [ x"" = x"$CROSS_COMPILE" ]; then
	if [ x"arm" == x"$ARCH" -o x"arm32" == x"$ARCH" ]; then
		export CROSS_COMPILE=arm-linux-gnueabihf-
	elif [ x"arm64" == x"$ARCH" -o x"aarch64" == x"$ARCH" ]; then
		export CROSS_COMPILE=aarch64-linux-gnu-
	fi
fi

export CC=${CROSS_COMPILE}gcc
export ARCH
export HOST=$(echo ${CROSS_COMPILE} | sed 's/.$//')

echo "ARCH=$ARCH"
echo "HOST=$HOST"
echo "CROSS_COMPILE=$CROSS_COMPILE"
echo "CC=$CC"

if [ x"arm" == x"$ARCH" -o x"arm32" == x"$ARCH" ]; then
	export TARGET=mini-rootfs-arm32
	APPLETS=$(ls applets/*arm32.tar.gz)
elif [ x"arm64" == x"$ARCH" -o x"aarch64" == x"$ARCH" ]; then
	export TARGET=mini-rootfs-arm64
	APPLETS=$(ls applets/*arm64.tar.gz)
fi

PATH_ROOTFS=${PWD}/${TARGET}
PATH_APPLET=${PWD}/applets
echo APPLETS=$APPLETS

# build file system hierarchy
mkdir -p ${PATH_ROOTFS}
pushd ${PATH_ROOTFS}
mkdir -p bin boot dev etc home lib mnt opt proc root run sbin sys tmp usr var 
popd

# build busybox
if [ -d busybox ]; then
	echo update busybox
	git pull origin master
else
	echo download busybox
	git clone git://busybox.net/busybox.git
fi

pushd busybox/
git clean -dxf
# avoid error when cross-compile for arm32, 
# error: ‘MTD_FILE_MODE_RAW’ undeclared
if [ x"arm" == x"$ARCH" -o x"arm32" == x"$ARCH" ]; then
	cp /usr/include/mtd/ ./include/mtd/ -a
fi
make CROSS_COMPILE=${CROSS_COMPILE} defconfig
make install

PATH_INSTALL=$(grep -i CONFIG_PREFIX .config | cut -d '"' -f 2)
cp -frap ${PATH_INSTALL}/* ${PATH_ROOTFS}
ln -s /sbin/init ${PATH_ROOTFS}/init
popd

# install applet
for patch in $APPLETS
do
	echo install applet: ${patch} ...
	tar -zxvf ${PWD}/${patch} -C ${PATH_ROOTFS}
done

# build dropbear
if [ -d dropbear ]; then
	echo update dropbear
	git pull origin master
else
	echo download dropbear
	git clone https://github.com/mkj/dropbear.git
fi

pushd dropbear/
git clean -dxf
aclocal
autoheader
autoconf

./configure --prefix=${PATH_ROOTFS} --host=${HOST} --disable-zlib \
	CC=${CROSS_COMPILE}gcc \
	LDFLAGS="-Wl,--gc-sections" \
	CFLAGS="-ffunction-sections -fdata-sections -Os"

make PROGRAMS="dropbear dbclient dropbearkey dropbearconvert scp" strip
make PROGRAMS="dropbear dbclient dropbearkey dropbearconvert scp" install
ln -s /bin/dbclient ${PATH_ROOTFS}/usr/bin/dbclient
popd

# compress file system
pushd ${PATH_ROOTFS}
find . | cpio -o -H newc | gzip > ../${TARGET}.cpio.gz
popd

# finished
echo Congratulations, the ${TARGET}.cpio.gz has been created!
