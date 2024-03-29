#!/bin/sh

# (c) liberodark


MIRROR_DRIVE="/mnt/mirror"
# check if mirror drive mounted
mount -t nfs -l | grep "${MIRROR_DRIVE}" > /dev/null
if [ $? -ne 0 ]; then
    echo "Error: NFS disk is not mounted to ${MIRROR_DRIVE}"
    exit 1
else
    echo "Mirror drive ready: ${MIRROR_DRIVE}"
fi

# This is a sample mirroring script.
HOME=$MIRROR_DRIVE
TARGET="${HOME}/debian"
TMP="${HOME}/.tmp/debian"
LOCK="/tmp/rsync-debian.lock"
#EXCLUDE="${alpha arm armel armhf hppa hurd-i386 i386 ia64 kfreebsd-amd64 kfreebsd-i386 m68k mipsel mips powerpc s390 s390x sh sparc source}"

# NOTE: You'll probably want to change this or remove the --bwlimit setting in
# the rsync call below. Here, rsync will be throttled to 
# a bandwidth of 10000kb/second or 9.7MB/s approximately:
# (the unit is KiB/s)
BWLIMIT=10000

SOURCE="rsync://ftp.fr.debian.org/debian/"

[ ! -d "${TARGET}" ] && mkdir -p "${TARGET}"
[ ! -d "${TMP}" ] && mkdir -p "${TMP}"

exec 9>"${LOCK}"
flock -n 9 || exit

#if ! stty &>/dev/null; then
#    QUIET="-q"
#fi

# show msg on NAS display
# /usr/bin/rnutil rn_lcd -s "MIRRORING Debian Repo" -p 1 -e 3600 -k 476


rsync \
    --exclude 'source*' \
    --exclude '*.debian.tar.xz' \
    --exclude '*.orig.tar.xz' \
    --exclude '*.orig.tar.bz2' \
    --exclude '*.dsc' \
    --exclude '*_arm64.deb' \
    --exclude '*_armel.deb' \
    --exclude '*_armhf.deb' \
    --exclude '*_i386.deb' \
    --exclude '*_mips.deb' \
    --exclude '*_mips64el.deb' \
    --exclude '*_mipsel.deb' \
    --exclude '*_ppc64el.deb' \
    --exclude '*_s390x.deb' \
    --exclude 'binary-arm64*' \
    --exclude 'binary-armel*' \
    --exclude 'binary-armhf*' \
    --exclude 'binary-i386*' \
    --exclude 'binary-mips*' \
    --exclude 'binary-mips64el*' \
    --exclude 'binary-mipsel*' \
    --exclude 'binary-ppc64el*' \
    --exclude 'binary-s390x*' \
    --exclude 'installer-arm64*' \
    --exclude 'installer-armel*' \
    --exclude 'installer-armhf*' \
    --exclude 'installer-i386*' \
    --exclude 'installer-mips*' \
    --exclude 'installer-mips64el*' \
    --exclude 'installer-mipsel*' \
    --exclude 'installer-ppc64el*' \
    --exclude 'installer-s390x*' \
    --exclude 'Contents-arm64*' \
    --exclude 'Contents-armel*' \
    --exclude 'Contents-armhf*' \
    --exclude 'Contents-i386*' \
    --exclude 'Contents-mips*' \
    --exclude 'Contents-mips64el*' \
    --exclude 'Contents-mipsel*' \
    --exclude 'Contents-ppc64el*' \
    --exclude 'Contents-s390x*' \
    --exclude 'Contents-udeb-arm64*' \
    --exclude 'Contents-udeb-armel*' \
    --exclude 'Contents-udeb-armhf*' \
    --exclude 'Contents-udeb-i386*' \
    --exclude 'Contents-udeb-mips*' \
    --exclude 'Contents-udeb-mips64el*' \
    --exclude 'Contents-udeb-mipsel*' \
    --exclude 'Contents-udeb-ppc64el*' \
    --exclude 'Contents-udeb-s390x*' \
    --recursive \
    --times \
    --links \
    --hard-links \
    --safe-links \
    --bwlimit=${BWLIMIT} \
    --delete-excluded \
    --timeout=600 \
    --contimeout=600 \
    --progress \
    --stats \
    --human-readable \
    --no-motd \
    --temp-dir="${TMP}" \
    "${SOURCE}" \
    "${TARGET}"

# /usr/bin/rnutil rn_lcd -s "" -p 1 -e 1 -k 476

# --perms \
# --delete-after \
# --delay-updates \
# --verbose \
#--info=progress2 \
