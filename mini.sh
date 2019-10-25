#!/bin/sh
#========************===========
#begin  last update 2011-09-28
#========*=*=*=*=*=*=*==========	
#VARS
PATH=/sbin:/bin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
. ./vars
#disable black screen
setterm -blank 0


rm -r $INSTALL_DIR
mkdir -p $INSTALL_DIR

#CREATE CATALOGS
mkdir $INSTALL_DIR/sys
mkdir $INSTALL_DIR/dev
mkdir $INSTALL_DIR/dev/pts
mkdir $INSTALL_DIR/dev/shm
mkdir $INSTALL_DIR/mnt
mkdir $INSTALL_DIR/mnt/hd
mkdir $INSTALL_DIR/mnt/cdrom
mkdir $INSTALL_DIR/mnt/lin
mkdir $INSTALL_DIR/etc
mkdir $INSTALL_DIR/sbin
mkdir $INSTALL_DIR/bin
mkdir $INSTALL_DIR/proc
mkdir $INSTALL_DIR/tmp
mkdir $INSTALL_DIR/opt
mkdir $INSTALL_DIR/lib
mkdir -p $INSTALL_DIR/var/log ##it's need for dropbear
mkdir -p $INSTALL_DIR/lib/modules
mkdir -p $BOOT_DIR


#
cd $SOURCE_DIR

### kernel prepare
tar -xjf ${KERNEL}.tar.bz2
cd ${KERNEL}
if [ $? == 0 ]
then
make allnoconfig    #its need
make                #because making file /include/utsrelease.h 
cd ..
else echo "cannot cd to ${KERNEL}"
fi
cp ../config-k ./${KERNEL}/.config          #copy config
# Firmwares for Realtek
tar -xzf ${FIRMWARE}.tar.gz
cp -r ./firmware-nonfree/realtek/rtl_nic ./${KERNEL}/firmware/
rm -r firmware-nonfree
# KERNELPATH for madwifi
export KERNELPATH=`pwd`/${KERNEL}

### MADWIFI
tar -xzf $MADWIFI.tar.gz
# patch madwifi
cd $MADWIFI
if [ $? == 0 ]
then
patch -Np1 -i ../${MADWIFI}-fix-install.patch
# patch kernel
cd patches
sh ./install.sh $KERNELPATH              #patching kernel
cd ../..
rm -r $MADWIFI
else echo "cannot cd to ${MADWIFI}"
fi
# compile tools

### WIRELESS TOOLS
tar -xjf $WIRELESS_TOOLS.tar.bz2
cd $WIRELESS_TOOLS
if [ $? == 0 ]
then
mkdir -p /tmp/wireless_tools
make
make PREFIX=/tmp/wireless_tools install
# copy tools
cp /tmp/wireless_tools/sbin/iwpriv /$INSTALL_DIR/sbin/
cp /tmp/wireless_tools/sbin/iwconfig /$INSTALL_DIR/sbin/
cp /tmp/wireless_tools/lib/libiw.so.29 /$INSTALL_DIR/lib
ln -s libiw.so.29 /$INSTALL_DIR/lib/libiw.so
cd ..
rm -r $WIRELESS_TOOLS
rm -r /tmp/wireless_tools
else echo "cannot cd to ${WIRELESS_TOOLS}"
fi

### kernel compile
cd $KERNEL
if [ $? == 0 ]
then
make
cp ./arch/i386/boot/bzImage $BOOT_DIR/kernel
make modules_install
cp -r /lib/modules/${VERSION} /$INSTALL_DIR/lib/modules/$VERSION
#remove some symlinks
rm /$INSTALL_DIR/lib/modules/$VERSION/build
rm /$INSTALL_DIR/lib/modules/$VERSION/source
cd ..
else echo "cannot cd to ${KERNEL}"
fi

### BUZYBOX
tar -xjf $BUZYBOX.tar.bz2
cp ../config-b $BUZYBOX/.config
cd $BUZYBOX
if [ $? == 0 ]
then
make && make install
cp -r ./_install/* $INSTALL_DIR
cd ..
rm -r $BUZYBOX
else echo "cannot cd to ${BUSYBOX}"
fi

### PCIUTILS
tar -xjf $PCIUTILS.tar.bz2
cd $PCIUTILS
if [ $? == 0 ]
then
make PREFIX=$INSTALL_DIR MANDIR=/tmp/man install
cd ..
rm -r $PCIUTILS
else echo "cannot cd to ${PCIUTILS}"
fi

### DMIDECODE
tar -xjf ${DMIDECODE}.tar.bz2
cd ${DMIDECODE}
if [ $? == 0 ]
then
# patch Dmidecode
patch -Np1 -i ../${DMIDECODE}-length.patch
patch -Np1 -i ../${DMIDECODE}-makefile-fix.patch
#make
make prefix=$INSTALL_DIR mandir=/tmp/man man8dir=/tmp/man8 install
cd ..
rm -r $DMIDECODE
rm -r /tmp/man 
rm -r /tmp/man8
else echo "cannot cd to ${DMIDECODE}"
fi

### FUSE
tar -xzf $FUSE.tar.gz
cd $FUSE
if [ $? == 0 ]
then
./configure --prefix=$INSTALL_DIR --mandir=/tmp/man --docdir=/tmp/doc --infodir=/tmp/info
make && make install
cd ..
rm -r $FUSE
rm -r /tmp/man
rm -r /tmp/doc
rm -r /tmp/info
else echo "cannot cd to ${FUSE}"
fi

### NTFSPROGS
tar -xjf $NTFSPROGS.tar.bz2
cd $NTFSPROGS
if [ $? == 0 ]
then
./configure --prefix=$INSTALL_DIR --enable-ntfsmount --mandir=/tmp/man --docdir=/tmp/doc --infodir=/tmp/info --localedir=/tmp/locale
make && make install
cd ..
rm -r $NTFSPROGS
rm -r /tmp/man
rm -r /tmp/doc
rm -r /tmp/info
rm -r /tmp/locale
else echo "cannot cd to ${NTFSPROGS}"
fi

#### LFTP
tar -xjf $LFTP.tar.bz2
cd $LFTP
if [ $? == 0 ]
then
./configure --prefix=$INSTALL_DIR --infodir=/tmp/info --mandir=/tmp/man --docdir=/tmp/doc
make && make install
cd ..
rm -r $LFTP
rm -r /tmp/info
rm -r /tmp/man
rm -r /tmp/doc
else echo "cannot cd to ${LFTP}"
fi

### LIBPNG
tar -xjf $LIBPNG.tar.bz2
cd $LIBPNG
if [ $? == 0 ]
then
./configure --prefix=$INSTALL_DIR/usr/local --infodir=/tmp/info --includedir=/tmp/include --mandir=/tmp/man --docdir=/tmp/doc --enable-static
make && make install
cd ..
rm -r $LIBPNG
rm -r /tmp/man
rm -r /tmp/doc
rm -r /tmp/include
rm -r /tmp/info
else echo "cannot cd to ${LIBPNG}"
fi

### GLIB2
tar -xjf $GLIB2.tar.bz2
cd $GLIB2
if [ $? == 0 ]
then
./configure --prefix=$INSTALL_DIR --mandir=/tmp/man --docdir=/tmp/doc --includedir=/tmp/include --enable-gtk-doc=no --enable-static --localedir=/tmp
make && make install
cd ..
rm -r $GLIB2
rm -r /tmp/man
rm -r /tmp/doc
rm -r /tmp/include
else echo "cannot cd to ${GLIB2}"
fi


### DIRECT FB
tar -xjf $DIRECTFB.tar.bz2
cd ./$DIRECTFB
if [ $? == 0 ]
then
./configure  --prefix=/usr/local --mandir=/tmp/man --docdir=/tmp/doc --includedir=/tmp/include --disable-x11 --enable-video4linux --enable-static
make
make exec_prefix=$INSTALL_DIR/usr/local install
cd ..
rm -r $DIRECTFB
rm -r /tmp/man
rm -r /tmp/doc
rm -r /tmp/include
else echo "cannot cd to ${DIRECTFB}"
fi


#### SPLASHY
tar -xjf $SPLASHY.tar.bz2
cd $SPLASHY
if [ $? == 0 ]
then
patch -Np1 -i ../$SPLASHY.patch
./configure --prefix=$INSTALL_DIR --infodir=/tmp/info --mandir=/tmp/man --docdir=/tmp/doc --includedir=/tmp/include --enable-static
make && make install
cd ..
rm -r $SPLASHY
rm -r /tmp/man
rm -r /tmp/info
rm -r /tmp/doc
rm -r /tmp/include
rm $INSTALL_DIR/etc/splashy/themes
ln -s /share/splashy/themes $INSTALL_DIR/etc/splashy/themes
cp config.xml $INSTALL_DIR/etc/splashy/config.xml
else echo "cannot cd to ${SPLASHY}"
fi

###DROPBEAR
tar -xjf $DROPBEAR.tar.bz2
cd $DROPBEAR
if [ $? == 0 ]
then
./configure --prefix=/tmp/dropbear
make
make install
cp /tmp/dropbear/sbin/dropbear $INSTALL_DIR/sbin/dropbear
cd ..
rm -r $DROPBEAR
else echo "cannot cd to ${DROPBEAR}"
fi

###SCREEN
tar -xjf $SCREEN.tar.bz2
cd $SCREEN
if [ $? == 0 ]
then
mkdir -p /tmp/screen
./configure --prefix=/tmp/screen
make
make install
cp /tmp/screen/bin/screen-4.0.3 $INSTALL_DIR/bin/screen
rm -r /tmp/screen
chmod -u+xrw $INSTALL_DIR/bin/screen
cd ..
rm -r $SCREEN
else echo "cannot cd to ${SCREEN}"
fi


### REGED
tar -xjf $CHNTPW.tar.bz2
cp ./$CHNTPW/reged.static $INSTALL_DIR/bin/reged
chmod -u+xrw $INSTALL_DIR/bin/reged
rm -r $CHNTPW

### GRUB
tar -xjf $GRUB.tar.bz2
cd $GRUB
if [ $? == 0 ]
then
patch -Np1 -i ../$GRUB-bc_partition.patch
./configure --prefix=$INSTALL_DIR --mandir=/tmp/man --infodir=/tmp/info
make
make install
cd ..
rm -r $GRUB
rm -r /tmp/man
rm -r /tmp/info
else echo "cannot cd to ${GRUB}"
fi

### TERMINFO
mkdir -p $INSTALL_DIR/usr/share/terminfo
tar -xjf $TERMINFO.tar.bz2 
cp -r ./$TERMINFO/* $INSTALL_DIR/usr/share/terminfo/
rm -r $TERMINFO

## SETTERM
cp ./setterm $INSTALL_DIR/bin/setterm

### BACKGROUND
cp ./background.png $INSTALL_DIR/share/splashy/themes/default/background.png

###SCRIPTS
tar -xjf ${SCRIPTS}.tar.bz2
cp -r ./${SCRIPTS}/etc/* $INSTALL_DIR/etc/
cp -r ./${SCRIPTS}/opt/* $INSTALL_DIR/opt/
cp -r ./${SCRIPTS}/udhcpc $INSTALL_DIR/usr/share
cp ./${SCRIPTS}/grub/* $INSTALL_DIR/sbin/
rm -r ${SCRIPTS}

### DEVS
tar -xjf $DEV.tar.bz2
cp -r ./$DEV/* $INSTALL_DIR/dev/
rm -r $DEV

### LIBS
tar -xjf $LIB.tar.bz2
cp -r ./$LIB/* $INSTALL_DIR/lib
cp /usr/lib/libgcc_s.so $INSTALL_DIR/usr/local/lib/libgcc_s.so
cp /usr/lib/libgcc_s.so.1 $INSTALL_DIR/usr/local/lib/libgcc_s.so.1
rm -r $LIB


#EXIT FROM SOURCES
cd ..           



### LDCONFIG
cp /sbin/ldconfig $INSTALL_DIR/sbin/
cat > $INSTALL_DIR/etc/ld.so.conf <<EOF
#BEGIN

/usr/local/lib
/usr/lib

#END
EOF




#CHROOT
cp chr.sh $INSTALL_DIR
chroot $INSTALL_DIR /bin/sh /chr.sh
rm $INSTALL_DIR/chr.sh



#INITRAMFS
cd $INSTALL_DIR
find .|cpio -o -H newc|gzip -9 > $BOOT_DIR/init.cpio.gz

##************#*#-*-*-*-*-*-*-*-*-*-*-*
#		   END
##**************----------**************