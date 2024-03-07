#!/bin/sh

LOCK="/tmp/update_crates.lock"

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

# show message on the NAS display
# /usr/bin/rnutil rn_lcd -s "MIRROR CRATES" -p 1 -e 3600 -k 476

./bin/panamax $MIRROR_DRIVE/crates/