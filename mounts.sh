#!/bin/sh

. vars1

mount -v --bind /dev $INSTALL_DIR/dev
mount -vt devpts devpts $INSTALL_DIR/dev/pts
mount -vt proc proc $INSTALL_DIR/proc
mount -vt tmpfs shm $INSTALL_DIR/dev/shm
mount -vt sysfs sysfs $INSTALL_DIR/sys