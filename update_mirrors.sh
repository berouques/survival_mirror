#!/bin/sh

LOCK="/tmp/update_mirrors.lock"
BWLIMIT=10000 # KBps
MIRROR_DRIVE="/mnt/mirror"
# check if mirror drive mounted
mount -t nfs -l | grep "${MIRROR_DRIVE}" > /dev/null
if [ $? -ne 0 ]; then
    echo "Error: NFS disk is not mounted to ${MIRROR_DRIVE}"
    exit 1
else
    echo "Mirror drive ready: ${MIRROR_DRIVE}"
fi


exec 9>"${LOCK}"
flock -n 9 || exit


echo "\n\n"
echo "====== MIRRORING STARTED " $(date -u '+%F %T.%6NZ')

lcd() {
    echo ""
    # showing message on the NAS LCD for 3600 sec
    # /usr/bin/rnutil rn_lcd -s "${1}" -p 1 -e 3600 -k 476
}

lcd_cls() {
    echo ""
    # clear NAS LCD
    # /usr/bin/rnutil rn_lcd -s "" -p 1 -e 1 -k 478
}

mirror() {
    
    TARGET="${MIRROR_DRIVE}/${2}"
    TMP="${MIRROR_DRIVE}/.tmp/${2}"
    
    [ ! -d "${TARGET}" ] && mkdir -p "${TARGET}"
    [ ! -d "${TMP}" ] && mkdir -p "${TMP}"
    
    lcd "MIRRORING ${2}"
    echo "\n============ Current task: ${2}\n"
    /usr/bin/rsync --info=progress2 --stats --human-readable --no-motd \
    --recursive \
    --times \
    --links \
    --hard-links \
    --safe-links \
    --delay-updates \
    --delete-after \
    --delete-excluded \
    --bwlimit=${BWLIMIT} \
    --timeout=600 \
    --contimeout=120 \
    --temp-dir="${TMP}" \
    $1 \
    "${TARGET}"
}


# 2TB (04/03/2024)
#mirror rsync://mirror.yandex.ru/macports macports

# 500GB (04/03/2024)
#mirror rsync://ftp.fau.de/turnkeylinux/images/iso/ turnkeylinux

# 100GB (04/03/2024)
mirror rsync://mirror.yandex.ru/mirrors/ftp.cygwin.com/ cygwin

# 430GB (04/03/2024)
mirror rsync://ftp.fau.de/fdroid/repo/ fdroid
[ -f "/data/mirror/fdroid/index.html" ] && mv /data/mirror/fdroid/index.html /data/mirror/fdroid/index_.html

# 26GB (04/03/2024)
mirror rsync://packages.termux.dev/termux termux

# 14GB (04/03/2024)
mirror rsync://ftp.fau.de/debian-cd/current/amd64/ debian_cd

# 32GB (04/03/2024)
mirror rsync://ftp.fau.de/ubuntu-releases ubuntu_cd

# 5GB (04/03/2024)
mirror rsync://ftp.fau.de/tails/stable/ tails

# 26GB (04/03/2024)
mirror rsync://mirror.yandex.ru/ubuntu-cloud-images/wsl/ wsl_ubuntu

# download the lates WSL linux packages AppxBundle
# 3GB  (04/03/2024)
WSLDIR="${MIRROR_DRIVE}/wsl_appxbundle"
mkdir -p $WSLDIR
lcd "DOWNLOADING Ubuntu AppxBundle"
wget --no-clobber --content-disposition -P $WSLDIR https://aka.ms/wslubuntu
rm `ls ${WSLDIR}/Ubuntu* -t | awk 'NR>1'` # remove all but the newest

lcd "DOWNLOADING Debian AppxBundle"
wget --no-clobber --content-disposition -P $WSLDIR https://aka.ms/wsl-debian-gnulinux
rm `ls ${WSLDIR}/TheDebian* -t | awk 'NR>1'` # remove all but the newest

lcd "DOWNLOADING KaliLinux AppxBundle"
wget --no-clobber --content-disposition -P $WSLDIR https://aka.ms/wsl-kali-linux-new
rm `ls ${WSLDIR}/KaliLinux* -t | awk 'NR>1'` # remove all but the newest


echo "\n"
echo "====== MIRRORING FINISHED " $(date -u '+%F %T.%6NZ')
echo "\n\n\n"


lcd_cls
