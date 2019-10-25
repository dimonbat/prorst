#!/bin/sh

cd /umpo
find .|cpio -o -H newc|gzip -9 > /boot/umpo.cpio.gz
