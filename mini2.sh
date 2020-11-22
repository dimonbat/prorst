#!/bin/sh


#VARS
#PATH=/sbin:/bin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
. ./vars

#disable black screen
setterm -blank 0

#make dirs and links
rm -r ${INSTALL_DIR}
mkdir -p ${INSTALL_DIR}
mkdir -p ${TOOLS_DIR}
ln -sv ${TOOLS_DIR} /


#Group and user
groupadd ${BUILDGROUP}

USERCOUNT=`cat /etc/passwd | grep -c "${BUILDUSER}"`
if [ ${USERCOUNT} -ne 1 ]
then
    echo "user ${BUILDUSER} not found. Create"
    useradd -s /bin/bash -g ${BUILDGROUP} -m -k /dev/null ${BUILDUSER}
    if [ $? -ne 0 ]
    then
	echo "cannot make user ${BUILDUSER}"
        exit 0
    fi
    
    #set user environment
    su -c "echo \"exec env -i HOME=\\\${HOME} TERM=\\\${TERM} PS1='\u:\w\\\\\$ ' /bin/bash\" > ~/.bash_profile" ${BUILDUSER}
    su -c "echo \"set +h\" > ~/.bashrc"  ${BUILDUSER}
    su -c "echo \"umask 022\" >> ~/.bashrc" ${BUILDUSER}
    su -c "echo \"LC_ALL=POSIX\" >> ~/.bashrc" ${BUILDUSER}
    su -c "echo \"LFS_TGT=\\\$(uname -m)-lfs-linux-gnu\" >> ~/.bashrc" ${BUILDUSER}
    su -c "echo \"PATH=/tools/bin:/bin:/usr/bin\" >> ~/.bashrc" ${BUILDUSER}
    su -c "echo \"export LC_ALL LFS_TGT PATH\" >> ~/.bashrc" ${BUILDUSER}    
    
    
    echo "user ${BUILDUSER} created. You need to set password"

fi
chown -v ${BUILDUSER} ${TOOLS_DIR}
chown -v ${BUILDUSER} ${SOURCE_DIR}


su -c "cd /repositories/prorst; . ./tools.sh" ${BUILDUSER}
chown -R root:root ${TOOLS_DIR}
chown -R root:root ${SOURCE_DIR}

# to test build tools
exit 0



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
cp ./configs/.config_kernel ./${KERNEL}/.config
# Firmwares for Realtek
xz -dkf ${FIRMWARE}.tar.xz
if [ $? == 0 ]
then
    tar -xf ${FIRMWARE}.tar
    cp -r ./${FIRMWARE}/rtl_nic ./${KERNEL}/firmware/
    rm -r ${FIRMWARE}
    rm ${FIRMWARE}.tar
else
    echo "cannot extract ${FIRMWARE}.tar.xz"
    exit 5
fi

# Firmwares for notebook lenovo 3000 G530 Broadcom WiFi
cp -r ./firmware/b43 ./${KERNEL}/firmware

# KERNELPATH for madwifi
export KERNELPATH=`pwd`/${KERNEL}

### MADWIFI
#tar -xzf ${MADWIFI}.tar.gz
# patch madwifi
#cd ${MADWIFI}
#if [ $? == 0 ]
#then
#    patch -Np1 -i ../${MADWIFI}-fix-install.patch
    # patch kernel
#    cd patches
#    sh ./install.sh ${KERNELPATH]              #patching kernel
#    cd ../..
#    rm -r ${MADWIFI}
#else echo "cannot cd to ${MADWIFI}"
#fi
# compile tools

### WIRELESS TOOLS
tar -xjf ${WIRELESS_TOOLS}.tar.bz2
cd ${WIRELESS_TOOLS}
if [ $? == 0 ]
then
#    mkdir -p /tmp/wireless_tools
    make
    make PREFIX=${INSTALL_DIR} install
    # copy tools
#    cp /tmp/wireless_tools/sbin/iwpriv /${INSTALL_DIR}/sbin/
#    cp /tmp/wireless_tools/sbin/iwconfig /$INSTALL_DIR/sbin/
#    cp /tmp/wireless_tools/lib/libiw.so.29 /$INSTALL_DIR/lib
#    ln -s libiw.so.29 /$INSTALL_DIR/lib/libiw.so
    cd ..
    rm -r ${WIRELESS_TOOLS}
#    rm -r /tmp/wireless_tools
else
    echo "cannot cd to ${WIRELESS_TOOLS}"
    exit 5
fi

### LibNL
tar -xzf ${LIBNL}.tar.gz
cd ${LIBNL}
if [ $? == 0 ]
then
    ./configure --prefix=${INSTALL_DIR} --disable-static --sysconfdir=/etc
    make
    make install
    cd ..
    rm -r ${LIBNL}
else
    echo "cannot cd to ${LIBNL}"
    exit 5
fi


### Wpa_Supplicant
tar -xzf ${WPA_SUPPLICANT}.tar.gz
cd ${WPA_SUPPLICANT}
if [ $? == 0 ]
then
    cd wpa_supplicant
    if [ $? == 0 ]
    then
	cp ../../configs/.config_wpa-supplicant ./.config
        make
	install -v m755 wpa_{cli,passphrase,supplicant} ${INSTALL_DIR}/sbin/
        cd ../..
	rm -r ${WPA_SUPPLICANT}
    else
	echo "cannot cd to wpa_supplicant"	
	exit 5
    fi	
else
    echo "cannot cd to ${WPA_SUPPLICANT}"
    exit 5
fi


### kernel compile
cd ${KERNEL}
if [ $? == 0 ]
then
    make
    cp ./arch/i386/boot/bzImage ${BOOT_DIR}/kernel
    make modules_install
    cp -r /lib/modules/${VERSION} /${INSTALL_DIR}/lib/modules/${VERSION}
    #remove some symlinks
    rm /${INSTALL_DIR}/lib/modules/${VERSION}/build
    rm /${INSTALL_DIR}/lib/modules/${VERSION}/source
    cd ..
    #rm -r ${KERNEL}
else
    echo "cannot cd to ${KERNEL}"
    exit 5
fi

### BUZYBOX
tar -xjf ${BUZYBOX}.tar.bz2
cp ./configs/.config_busybox ${BUZYBOX}/.config
cd ${BUZYBOX}
if [ $? == 0 ]
then
    make && make install
    cp -r ./_install/* ${INSTALL_DIR}
    cd ..
    rm -r ${BUZYBOX}
else
    echo "cannot cd to ${BUSYBOX}"
    exit 5
fi

### PCIUTILS
tar -xjf ${PCIUTILS}.tar.bz2
cd ${PCIUTILS}
if [ $? == 0 ]
then
    make PREFIX=${INSTALL_DIR} MANDIR=/tmp/man install
    cd ..
    rm -r ${PCIUTILS}
else
    echo "cannot cd to ${PCIUTILS}"
    exit 5
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
    make prefix=${INSTALL_DIR} mandir=/tmp/man man8dir=/tmp/man8 install
    cd ..
    rm -r ${DMIDECODE}
    rm -r /tmp/man 
    rm -r /tmp/man8
else
    echo "cannot cd to ${DMIDECODE}"
    exit 5
fi

### FUSE
tar -xzf ${FUSE}.tar.gz
cd ${FUSE}
if [ $? == 0 ]
then
    ./configure --prefix=${INSTALL_DIR} --mandir=/tmp/man --docdir=/tmp/doc --infodir=/tmp/info
    make && make install
    cd ..
    rm -r ${FUSE}
    rm -r /tmp/man
    rm -r /tmp/doc
    rm -r /tmp/info
else
    echo "cannot cd to ${FUSE}"
    exit 5
fi

### NTFSPROGS
#tar -xjf ${NTFSPROGS}.tar.bz2
#cd ${NTFSPROGS}
#if [ $? == 0 ]
#then
#    ./configure --prefix=${INSTALL_DIR} --enable-ntfsmount --mandir=/tmp/man --docdir=/tmp/doc --infodir=/tmp/info --localedir=/tmp/locale
#    make && make install
#    cd ..
#    rm -r ${NTFSPROGS}
#    rm -r /tmp/man
#    rm -r /tmp/doc
#    rm -r /tmp/info
#    rm -r /tmp/locale
#else
#    echo "cannot cd to ${NTFSPROGS}"
#    exit 5
#fi

#### LFTP
tar -xjf ${LFTP}.tar.bz2
cd ${LFTP}
if [ $? == 0 ]
then
    ./configure --prefix=${INSTALL_DIR} --infodir=/tmp/info --mandir=/tmp/man --docdir=/tmp/doc
    make && make install
    cd ..
    rm -r ${LFTP}
    rm -r /tmp/info
    rm -r /tmp/man
    rm -r /tmp/doc
else
    echo "cannot cd to ${LFTP}"
    exit 5
fi

### LIBPNG
tar -xjf $LIBPNG.tar.bz2
cd ${LIBPNG}
if [ $? == 0 ]
then
    ./configure --prefix=$INSTALL_DIR/usr/local --infodir=/tmp/info --includedir=/tmp/include --mandir=/tmp/man --docdir=/tmp/doc --enable-static
    make && make install
    cd ..
    rm -r ${LIBPNG}
    rm -r /tmp/man
    rm -r /tmp/doc
    rm -r /tmp/include
    rm -r /tmp/info
else
    echo "cannot cd to ${LIBPNG}"
    exit 5
fi

### GLIB2
tar -xjf ${GLIB2}.tar.bz2
cd ${GLIB2}
if [ $? == 0 ]
then
    ./configure --prefix=${INSTALL_DIR} --mandir=/tmp/man --docdir=/tmp/doc --includedir=/tmp/include --enable-gtk-doc=no --localedir=/tmp
    make && make install
    cd ..
    rm -r ${GLIB2}
    rm -r /tmp/man
    rm -r /tmp/doc
    rm -r /tmp/include
else
    echo "cannot cd to ${GLIB2}"
    exit 5
fi


### DIRECT FB
tar -xjf ${DIRECTFB}.tar.bz2
cd ./${DIRECTFB}
if [ $? == 0 ]
then
    ./configure  --prefix=/usr/local --mandir=/tmp/man --docdir=/tmp/doc --includedir=/tmp/include --disable-x11 --enable-video4linux --enable-static
    make
    make exec_prefix=${INSTALL_DIR}/usr/local install
    cd ..
    rm -r ${DIRECTFB}
    rm -r /tmp/man
    rm -r /tmp/doc
    rm -r /tmp/include
else
    echo "cannot cd to ${DIRECTFB}"
    exit 5
fi


#### SPLASHY
tar -xjf ${SPLASHY}.tar.bz2
cd ${SPLASHY}
if [ $? == 0 ]
then
    patch -Np1 -i ../${SPLASHY}.patch
    ./configure --prefix=${INSTALL_DIR} --infodir=/tmp/info --mandir=/tmp/man --docdir=/tmp/doc --includedir=/tmp/include --enable-static
    make && make install
    cd ..
    rm -r ${SPLASHY}
    rm -r /tmp/man
    rm -r /tmp/info
    rm -r /tmp/doc
    rm -r /tmp/include
    rm ${INSTALL_DIR}/etc/splashy/themes
    ln -s /share/splashy/themes ${INSTALL_DIR}/etc/splashy/themes
    cp config.xml ${INSTALL_DIR}/etc/splashy/config.xml
else
    echo "cannot cd to ${SPLASHY}"
    exit 5
fi

###DROPBEAR
tar -xjf ${DROPBEAR}.tar.bz2
cd ${DROPBEAR}
if [ $? == 0 ]
then
    ./configure --prefix=${INSTALL_DIR} --mandir=/tmp/man
    make
    make install
    cp /tmp/dropbear/sbin/dropbear ${INSTALL_DIR}/sbin/dropbear
    cd ..
    rm -r ${DROPBEAR}
    rm -r /tmp/man
else
    echo "cannot cd to ${DROPBEAR}"
    exit 5
fi

###SCREEN
tar -xjf ${SCREEN}.tar.bz2
cd ${SCREEN}
if [ $? == 0 ]
then
    mkdir -p /tmp/screen
    ./configure --prefix=/tmp/screen
    make
    make install
    cp /tmp/screen/bin/screen-4.0.3 ${INSTALL_DIR}/bin/screen
    rm -r /tmp/screen
    chmod -u+xrw ${INSTALL_DIR}/bin/screen
    cd ..
    rm -r ${SCREEN}
else
    echo "cannot cd to ${SCREEN}"
    exit 5
fi


### REGED
tar -xjf ${CHNTPW}.tar.bz2
cp ./${CHNTPW}/reged.static ${INSTALL_DIR}/bin/reged
chmod -u+xrw ${INSTALL_DIR}/bin/reged
rm -r ${CHNTPW}

### GRUB
tar -xjf ${GRUB}.tar.bz2
cd ${GRUB}
if [ $? == 0 ]
then
    patch -Np1 -i ../${GRUB}-bc_partition.patch
    ./configure --prefix=${INSTALL_DIR} --mandir=/tmp/man --infodir=/tmp/info
    make
    make install
    cd ..
    rm -r ${GRUB}
    rm -r /tmp/man
    rm -r /tmp/info
else 
    echo "cannot cd to ${GRUB}"
    exit 5
fi


### NTFS-3G
tar -xzf ${NTFS3G}.tgz
cd ${NTFS3G}
if [ $? == 0 ]
then
    ./configure --prefix=${INSTALL_DIR}/usr --exec-prefix=${INSTALL_DIR}/usr --disable-static --with-fuse=internal --mandir=/tmp/man --docdir=/tmp/doc --includedir=/tmp/include
    make
    make install
    cd ..
    rm -r ${NTFS3G}
    rm -r /tmp/man
    rm -r /tmp/info
    rm -r /tmp/include
else 
    echo "cannot cd to ${NTFS3G}"
    exit 5
fi


### LIBUUID
tar -xzf ${LIBUUID}.tar.gz
cd ${LIBUUID}
if [ $? == 0 ]
then
    ./configure --prefix=/ --includedir=/tmp/include
    make
    make install
    cd ..
    rm -r ${LIBUUID}
    rm -r /tmp/include
else 
    echo "cannot cd to ${LIBUUID}"
    exit 5
fi


### PARTCLONE
tar -xzf ${PARTCLONE}.tar.gz
cd ${PARTCLONE}
if [ $? == 0 ]
then
    ./configure --enable-ntfs --enable-static --enable-ncursesw --prefix=${INSTALL_DIR}
    make
    make install
    cd ..
    rm -r ${PARTCLONE}
else
    echo "cannot cd to ${PARTCLONE}"
    exit 5
fi

### TERMINFO
mkdir -p ${INSTALL_DIR}/usr/share/terminfo
tar -xjf ${TERMINFO}.tar.bz2 
cp -r ./${TERMINFO}/* ${INSTALL_DIR}/usr/share/terminfo/
rm -r ${TERMINFO}

## SETTERM
cp ./setterm ${INSTALL_DIR}/bin/setterm

### BACKGROUND
cp ./background.png ${INSTALL_DIR}/share/splashy/themes/default/background.png


### add SCRIPTS and INSTALL sources from another repo
###SCRIPTS
#tar -xjf ${SCRIPTS}.tar.bz2
cp -r ../../${SCRIPTSREPO}/etc/* ${INSTALL_DIR}/etc/
cp -r ../../${SCRIPTSREPO}/opt/* ${INSTALL_DIR}/opt/
cp -r ../../${SCRIPTSREPO}/udhcpc ${INSTALL_DIR}/usr/share
cp ../../${SCRIPTSREPO}/grub/* ${INSTALL_DIR}/sbin/

### DEVS
tar -xjf ${DEV}.tar.bz2
cp -r ./${DEV}/* ${INSTALL_DIR}/dev/
rm -r ${DEV}

### LIBS
tar -xjf ${LIB}.tar.bz2
cp -r ./${LIB}/* ${INSTALL_DIR}/lib
cp /usr/lib/libgcc_s.so ${INSTALL_DIR}/usr/local/lib/libgcc_s.so
cp /usr/lib/libgcc_s.so.1 ${INSTALL_DIR}/usr/local/lib/libgcc_s.so.1
rm -r ${LIB}


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
cp chr.sh ${INSTALL_DIR}
chroot ${INSTALL_DIR} /bin/ash /chr.sh
rm ${INSTALL_DIR}/chr.sh



#INITRAMFS
cd ${INSTALL_DIR}
find .|cpio -o -H newc|gzip -9 > ${BOOT_DIR}/init.cpio.gz

#GEN md5sum
cd ${BOOT_DIR}
md5sum init.cpio.gz > init.md5sum
sed 's/init.cpio.gz/\/mnt\/lin\/boot\/init1.cpio.gz/' init.md5sum > init.md5sum.1
mv init.md5sum.1 init.md5sum

md5sum kernel > kernel.md5sum
sed 's/kernel/\/mnt\/lin\/boot\/kernel1/' kernel.md5sum > kernel.md5sum.1
mv kernel.md5sum.1 kernel.md5sum

##************#*#-*-*-*-*-*-*-*-*-*-*-*
#		   END
##**************----------**************