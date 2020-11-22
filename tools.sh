#!/bin/bash
. ./vars
. ~/.bashrc

BUILD_BINUTILS_P1=1
BUILD_GCC_P1=1
BUILD_KERNEL_HEADERS=1
BUILD_GLIBC=1
BUILD_BINUTILS_P2=1
BUILD_GCC_P2=1
BUILD_TCL=1
BUILD_EXPECT=1
BUILD_NCURSES=1
BUILD_BASH=1
BUILD_BZIP2=1
BUILD_COREUTILS=1
BUILD_DIFFUTILS=1
BUILD_FILE=1
BUILD_FINDUTILS=1
BUILD_GAWK=1
BUILD_GETTEXT=1
BUILD_GREP=1
BUILD_GZIP=1
BUILD_M4=1
BUILD_MAKE=1
BUILD_PATCH=1
BUILD_PERL=1
BUILD_SED=1
BUILD_TAR=1
BUILD_TEXINFO=1


#
cd ${SOURCE_DIR}

###########*************** TOOLS BUILD **********************
# Binutils Pass1
if [ ${BUILD_BINUTILS_P1} -eq 1 ]
then
    tar -xjf ${BINUTILS}.tar.bz2
    cd ${BINUTILS}
    if [ $? -ne 0 ]
    then
	echo "cannot cd to ${BINUTILS} Pass1"
        exit 0
    fi

    mkdir -v ../binutils-build
    cd ../binutils-build
    ../${BINUTILS}/configure --prefix=/tools --target=${LFS_TGT} --disable-nls --disable-werror
    make
    if [ $? -ne 0 ]
    then
	echo "cannot make ${BINUTILS}"
        exit 0
    fi
    make install
    # exit from build
    cd ..
    rm -rf ${BINUTILS}
fi

# GCC pass 1
if [ ${BUILD_GCC_P1} -eq 1 ]
then
    tar -xjf ${GCC}.tar.bz2
    cd ${GCC}
    if [ $? -ne 0 ]
    then
	echo "cannot cd to ${GCC}"
        exit 0
    fi

    # MPFR (need for GCC)
    tar -xjf ../${MPFR}.tar.bz2
    mv -v ${MPFR} mpfr
    tar -xjf ../${GMP}.tar.bz2
    mv -v ${GMP} gmp
    tar -xzf ../${MPC}.tar.gz
    mv -v ${MPC} mpc

    
    mkdir -v ../gccp1-build
    cd ../gccp1-build
    ../${GCC}/configure --target=${LFS_TGT} --prefix=/tools --disable-nls --disable-shared --disable-multilib --disable-decimal-float --disable-threads --disable-libmudflap --disable-libssp --disable-libgomp --enable-languages=c --with-gmp-include=$(pwd)/gmp --with-gmp-lib=$(pwd)/gmp/.libs --without-ppl --without-cloog
    if [ $? -ne 0 ]
    then
	echo "cannot configure ${GCC}"
        exit 0
    fi

    make
    if [ $? -ne 0 ]
    then
	echo "cannot make ${GCC} Pass1"
        exit 0
    fi

    make install
    if [ $? -ne 0 ]
    then
        echo "cannot install ${GCC}"
	exit 0
    fi

    ### ??
    ln -vs libgcc.a `${LFS_TGT}-gcc -print-libgcc-file-name | sed 's/libgcc/&_eh/'`
    #exit from build
    cd ..
    rm -rf ${GCC}
fi

#kernel headers for GlibC
if [ ${BUILD_KERNEL_HEADERS} -eq 1 ]
then
    tar -xjf ${KERNEL}.tar.bz2
    cd ${KERNEL}
    if [ $? -ne 0 ]
    then
	echo "cannot cd to ${KERNEL}"
        exit 0
    fi

    make mrproper
    make INSTALL_HDR_PATH=dest headers_install
    if [ $? -ne 0 ]
    then
	echo "cannot make ${KERNEL} headers"
        exit 0
    fi
    cp -rv dest/include/* /tools/include
    cd ..
fi

#GlibC
if [ ${BUILD_GLIBC} -eq 1 ]
then
    tar -xjf ${GLIBC}.tar.bz2
    cd ${GLIBC}
    if [ $? -ne 0 ]
    then
	echo "cannot cd to ${GLIBC}"
        exit 0
    fi

    patch -Np1 -i ../${GLIBC}-gcc_fix-1.patch
    patch -Np1 -i ../${GLIBC}-makefile_fix-1.patch

    mkdir -v ../glibc-build
    cd ../glibc-build

    case `uname -m` in
	i386) echo "CFLAGS += -march=i486 -mtune=native" > configparms ;;
    esac

    ../${GLIBC}/configure --prefix=/tools --host=${LFS_TGT} --build=$(../${GLIBC}/scripts/config.guess) --disable-profile --enable-add-ons --enable-kernel=2.6.22.5 --with-headers=/tools/include libc_cv_forced_unwind=yes libc_cv_c_cleanup=yes

    make
    if [ $? -ne 0 ]
    then
	echo "cannot make ${GLIBC}"
        exit 0
    fi
    make install
    SPECS=`dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/specs
    ${LFS_TGT}-gcc -dumpspecs | sed \
	-e 's@/lib\(64\)\?/ld@/tools&@g' \
        -e "/^\*cpp:$/{n;s,$, -isystem /tools/include,}" > ${SPECS}
    echo "New specs file is: ${SPECS}"
    unset SPECS
    cd ..
fi


## BINUTILS  Pass2
if [ ${BUILD_BINUTILS_P2} -eq 1 ]
then
    tar -xjf ${BINUTILS}.tar.bz2
    cd ${BINUTILS}
    if [ $? -ne 0 ]
    then
	echo "cannot cd to ${BINUTILS}"
        exit 0
    fi
    mkdir -v build2
    cd build2
    CC="${LFS_TGT}-gcc -B/tools/lib/" \
	AR=${LFS_TGT}-ar \
        RANLIB=${LFS_TGT}-ranlib \
	../configure --prefix=/tools \
	    --disable-nls \
	    --with-lib-path=/tools/lib
    make
    if [ $? -ne 0 ]
    then
	echo "cannot make ${BINUTILS} Pass2"
        exit 0
    fi
    make install
    if [ $? -ne 0 ]
    then
	echo "cannot install ${BINUTILS} Pass2"
        exit 0
    fi
    make -C ld clean
    make -C ld LIB_PATH=/usr/lib:/lib
    cp -v ld/ld-new /tools/bin
    #exit from build2
    cd ..
    #exit from binutils
    cd ..
fi

## GCC Pass2
if [ ${BUILD_GCC_P2} -eq 1 ]
then
    tar -xjf ${GCC}.tar.bz2
    cd ${GCC}
    if [ $? -ne 0 ]
    then
	echo "cannot cd to ${GCC}"
        exit 0
    fi
    patch -Np1 -i ../${GCC}-startfiles_fix-1.patch
    cp -v gcc/Makefile.in{,.orig}
    sed 's@\./fixinc\.sh@-c true@' gcc/Makefile.in.orig > gcc/Makefile.in
    cp -v gcc/Makefile.in{,.tmp}
    sed 's/^T_CFLAGS =$/& -fomit-frame-pointer/' gcc/Makefile.in.tmp > gcc/Makefile.in


    for file in $(find gcc/config -name linux64.h -o -name linux.h -o -name sysv4.h)
    do
	cp -uv ${file}{,.orig}
        sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' \
            -e 's@/usr@/tools@g' ${file}.orig > ${file}
        echo '
#undef STANDARD_INCLUDE_DIR
#define STANDARD_INCLUDE_DIR 0
#define STANDARD_STARTFILE_PREFIX_1 ""
#define STANDARD_STARTFILE_PREFIX_2 ""' >> ${file}
	touch ${file}.orig
    done

    case $(uname -m) in
	x86_64)
	    for file in $(find gcc/config -name t-linux64) ; do \
		cp -v ${file}{,.orig}
	        sed '/MULTILIB_OSDIRNAMES/d' ${file}.orig > ${file}
	    done
        ;;
    esac

    # MPFR, GMP, MPC (need for GCC)
    tar -xjf ../${MPFR}.tar.bz2
    mv -v ${MPFR} mpfr
    tar -xjf ../${GMP}.tar.bz2
    mv -v ${GMP} gmp
    tar -xzf ../${MPC}.tar.gz
    mv -v ${MPC} mpc

    mkdir -v ../gcc-build2
    cd ../gcc-build2

    CC="${LFS_TGT}-gcc -B/tools/lib/" AR=${LFS_TGT}-ar RANLIB=${LFS_TGT}-ranlib ../${GCC}/configure --prefix=/tools --with-local-prefix=/tools --enable-clocale=gnu --enable-shared --enable-threads=posix --enable-__cxa_atexit --enable-languages=c,c++ --disable-libstdcxx-pch --disable-multilib --disable-bootstrap --disable-libgomp --with-gmp-include=$(pwd)/gmp --with-gmp-lib=$(pwd)/gmp/.libs --without-ppl --without-cloog
    make
    if [ $? -ne 0 ]
    then
	echo "cannot make ${GCC} Pass2"
        exit 0
    fi
    make install
    ln -vs gcc /tools/bin/cc
    
    cd ..
fi

# TCL
if [ ${BUILD_TCL} -eq 1 ]
then
    tar -xzf ${TCL}-src.tar.gz
    cd ${TCL}
    if [ $? -ne 0 ]
    then
	echo "cannot cd to ${TCL}"
        exit 0
    fi

    cd unix
    ./configure --prefix=/tools
    make
    make install
    chmod -v u+w /tools/lib/libtcl8.5.so
    make install-private-headers
    ln -sv tclsh8.5 /tools/bin/tclsh

    ## exit from unix
    cd ..
    ## exit from tcl
    cd ..
fi

# Expect
if [ ${BUILD_EXPECT} -eq 1 ]
then
    tar -xjf ${EXPECT}.tar.bz2
    cd ${EXPECT}
    if [ $? -ne 0 ]
    then
	echo "cannot cd to ${EXPECT}"
        exit 0
    fi

    patch -Np1 -i ../${EXPECT}-no_tk-1.patch
    cp -v configure{,.orig}
    sed 's:/usr/local/bin:/bin:' configure.orig > configure
    ./configure \
	--prefix=/tools \
        --with-tcl=/tools/lib \
	--with-tclinclude=/tools/include \
        --with-tk=no
    make
    if [ $? -ne 0 ]
    then
	echo "cannot make ${EXPECT}"
        exit 0
    fi
    make SCRIPTS="" install
    cd ..

    # Dejagnu
    tar -xzf ${DEJAGNU}.tar.gz
    cd ${DEJAGNU}
    if [ $? -ne 0 ]
    then
	echo "cannot cd to ${DEJAGNU}"
        exit 0
    fi
    patch -Np1 -i ../${DEJAGNU}-consolidated-1.patch
    ./configure --prefix=/tools
    make install
    cd ..
fi


# NCURSES
if [ ${BUILD_NCURSES} -eq 1 ]
then
    tar -xzf ${NCURSES}.tar.gz
    cd ${NCURSES}
    if [ $? -ne 0 ]
    then
	echo "cannot cd to ${NCURSES}"
        exit 0
    fi
    ./configure \
	--prefix=/tools \
        --with-shared \
	--without-debug \
        --without-ada \
	--enable-overwrite
    make
    if [ $? -ne 0 ]
    then
	echo "cannot make ${NCURSES}"
        exit 0
    fi
    make install
    cd ..
fi

# BASH
if [ ${BUILD_BASH} -eq 1 ]
then
    tar -xzf ${BASH}.tar.gz
    cd ${BASH}
    if [ $? -ne 0 ]
    then
	echo "cannot cd to ${BASH}"
        exit 0
    fi
    patch -Np1 -i ../${BASH}-fixes-2.patch
    ./configure --prefix=/tools --without-bash-malloc
    make
    if [ $? -ne 0 ]
    then
	echo "cannot make ${BASH}"
        exit 0
    fi
    make install
    ln -vs bash /tools/bin/sh
    cd ..
fi


# BZIP2
if [ ${BUILD_BZIP2} -eq 1 ]
then
    tar -xzf ${BZIP2}.tar.gz
    cd ${BZIP2}
    if [ $? -ne 0 ]
    then
	echo "cannot cd to ${BZIP2}"
        exit 0
    fi
    make
    if [ $? -ne 0 ]
    then
	echo "cannot make ${BZIP2}"
        exit 0
    fi
    make PREFIX=/tools install
    cd ..
fi


# COREUTILS
if [ ${BUILD_COREUTILS} -eq 1 ]
then
    tar -xzf ${COREUTILS}.tar.gz
    cd ${COREUTILS}
    if [ $? -ne 0 ]
    then
	echo "cannot cd to ${COREUTILS}"
        exit 0
    fi
    ./configure --prefix=/tools --enable-install-program=hostname
    make
    if [ $? -ne 0 ]
    then
	echo "cannot make ${COREUTILS}"
        exit 0
    fi
    make install
    cp -v src/su /tools/bin/su-tools
    cd ..
fi

# DIFFUTILS
if [ ${BUILD_DIFFUTILS} -eq 1 ]
then
    tar -xzf ${DIFFUTILS}.tar.gz
    cd ${DIFFUTILS}
    if [ $? -ne 0 ]
    then
	echo "cannot cd to ${DIFFUTILS}"
        exit 0
    fi
    ./configure --prefix=/tools
    make
    make install
    cd ..
fi

# FILE
if [ ${BUILD_FILE} -eq 1 ]
then
    tar -xzf ${FILE}.tar.gz
    cd ${FILE}
    if [ $? -ne 0 ]
    then
	echo "cannot cd to ${FILE}"
        exit 0
    fi
    ./configure --prefix=/tools
    make
    if [ $? -ne 0 ]
    then
	echo "cannot make ${FILE}"
        exit 0
    fi
    make install
    cd ..
fi

# FINDUTILS
if [ ${BUILD_FINDUTILS} -eq 1 ]
then
    tar -xzf ${FINDUTILS}.tar.gz
    cd ${FINDUTILS}
    if [ $? -ne 0 ]
    then
	echo "cannot cd to ${FINDUTILS}"
        exit 0
    fi
    ./configure --prefix=/tools
    make
    if [ $? -ne 0 ]
    then
	echo "cannot make ${FINDUTILS}"
        exit 0
    fi
    make install
    cd ..
fi


# GAWK
if [ ${BUILD_GAWK} -eq 1 ]
then
    tar -xjf ${GAWK}.tar.bz2
    cd ${GAWK}
    if [ $? -ne 0 ]
    then
	echo "cannot cd to ${GAWK}"
        exit 0
    fi
    ./configure --prefix=/tools
    make
    if [ $? -ne 0 ]
    then
	echo "cannot make ${GAWK}"
        exit 0
    fi
    make install
    cd ..
fi


# Gettext (only 1 binary - msgfmt)
if [ ${BUILD_GETTEXT} -eq 1 ]
then
    tar -xzf ${GETTEXT}.tar.gz
    cd ${GETTEXT}
    if [ $? -ne 0 ]
    then
	echo "cannot cd to ${GETTEXT}"
        exit 0
    fi
    cd gettext-tools
    ./configure --prefix=/tools --disable-shared
    make -C gnulib-lib
    if [ $? -ne 0 ]
    then
	echo "cannot make ${GETTEXT}"
        exit 0
    fi
    make -C src msgfmt
    if [ $? -ne 0 ]
    then
	echo "cannot make ${GETTEXT} msgfmt"
        exit 0
    fi
    cp -v src/msgfmt /tools/bin
    # exit from gettext-tools
    cd ..
    # exit from gettext
    cd ..
fi


# GREP
if [ ${BUILD_GREP} -eq 1 ]
then
    tar -xzf ${GREP}.tar.gz
    cd ${GREP}
    if [ $? -ne 0 ]
    then
	echo "cannot cd to ${GREP}"
        exit 0
    fi
    ./configure --prefix=/tools --disable-perl-regexp
    make
    if [ $? -ne 0 ]
    then
	echo "cannot make ${GREP}"
        exit 0
    fi
    make install
    cd ..
fi


# GZIP
if [ ${BUILD_GZIP} -eq 1 ]
then
    tar -xzf ${GZIP}.tar.gz
    cd ${GZIP}
    if [ $? -ne 0 ]
    then
	echo "cannot cd to ${GZIP}"
        exit 0
    fi
    ./configure --prefix=/tools
    make
    if [ $? -ne 0 ]
    then
	echo "cannot make ${GZIP}"
        exit 0
    fi
    make install
    cd ..
fi


# M4
if [ ${BUILD_M4} -eq 1 ]
then
    tar -xjf ${M4}.tar.bz2
    cd ${M4}
    if [ $? -ne 0 ]
    then
	echo "cannot cd to ${M4}"
        exit 0
    fi
    sed -i -e '/"m4.h"/a\
#include <sys/stat.h>' src/path.c
    ./configure --prefix=/tools
    make
    if [ $? -ne 0 ]
    then
	echo "cannot make ${M4}"
        exit 0
    fi
    make install
    cd ..
fi


# MAKE
if [ ${BUILD_MAKE} -eq 1 ]
then
    tar -xjf ${MAKE}.tar.bz2
    cd ${MAKE}
    if [ $? -ne 0 ]
    then
	echo "cannot cd to ${MAKE}"
        exit 0
    fi
    ./configure --prefix=/tools
    make
    if [ $? -ne 0 ]
    then
	echo "cannot make ${MAKE}"
        exit 0
    fi
    make install
    cd ..
fi


# PATCH
if [ ${BUILD_PATCH} -eq 1 ]
then
    tar -xjf ${PATCH}.tar.bz2
    cd ${PATCH}
    if [ $? -ne 0 ]
    then
	echo "cannot cd to ${PATCH}"
        exit 0
    fi
    ./configure --prefix=/tools
    make
    if [ $? -ne 0 ]
    then
	echo "cannot make ${PATCH}"
        exit 0
    fi
    make install
    cd ..
fi


# PERL
if [ ${BUILD_PERL} -eq 1 ]
then
    tar -xjf ${PERL}.tar.bz2
    cd ${PERL}
    if [ $? -ne 0 ]
    then
	echo "cannot cd to ${PERL}"
        exit 0
    fi
    patch -Np1 -i ../${PERL}-libc-1.patch
    sh Configure -des -Dprefix=/tools -Dstatic_ext='Data/Dumper Fcntl IO'
    make perl utilities ext/Errno/pm_to_blib
    if [ $? -ne 0 ]
    then
	echo "cannot make ${PERL}"
        exit 0
    fi
    cp -v perl pod/pod2man /tools/bin
    mkdir -pv /tools/lib/perl5/5.12.1
    cp -Rv lib/* /tools/lib/perl5/5.12.1
    cd ..
fi


# SED
if [ ${BUILD_SED} -eq 1 ]
then
    tar -xjf ${SED}.tar.bz2
    cd ${SED}
    if [ $? -ne 0 ]
    then
	echo "cannot cd to ${SED}"
        exit 0
    fi
    ./configure --prefix=/tools
    make
    if [ $? -ne 0 ]
    then
	echo "cannot make ${SED}"
        exit 0
    fi
    make install
    cd ..
fi


# TAR
if [ ${BUILD_TAR} -eq 1 ]
then
    tar -xjf ${TAR}.tar.bz2
    cd ${TAR}
    if [ $? -ne 0 ]
    then
	echo "cannot cd to ${TAR}"
        exit 0
    fi
    sed -i /SIGPIPE/d src/tar.c
    ./configure --prefix=/tools
    make
    if [ $? -ne 0 ]
    then
	echo "cannot make ${TAR}"
        exit 0
    fi
    make install
    cd ..
fi


# TEXINFO
if [ ${BUILD_TEXINFO} -eq 1 ]
then
    tar -xzf ${TEXINFO}a.tar.gz
    cd ${TEXINFO}
    if [ $? -ne 0 ]
    then
	echo "cannot cd to ${TEXINFO}"
        exit 0
    fi
    ./configure --prefix=/tools
    make
    if [ $? -ne 0 ]
    then
	echo "cannot make ${TEXINFO}"
        exit 0
    fi
    make install
    cd ..
fi


