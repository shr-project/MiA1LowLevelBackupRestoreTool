#!/sbin/sh

if [ $# -ne 2 ] ; then
    echo "Usage $0 directory-to-backup file-with-list-of-partitions-to-backup"
    exit 1
fi

if [ ! -d $1 ] ; then
    echo "First parameter '$1' isn't a directory"
    echo "Enter 'Y' to create it or anything else to exit"
    read A
    if [ "${A}" != "Y" ] ; then
        exit 2
    fi
    mkdir -p $1
else
    if ls $1/* 2>/dev/null >/dev/null; then
        echo "$1 already exists and it's not empty:"
        ls $1/*
        echo "Enter 'Y' to empty it or anything else to exit"
        read A
        if [ "${A}" != "Y" ] ; then
            exit 2
        fi
        rm -rf $1/*
    fi
fi
if [ ! -f $2 ] ; then
    echo "Second parameter '$2' isn't a file with list of partitions to restore"
    exit 3
fi

DIR=`echo $1 | sed 's#/$##'`
PARTITIONS=`cat $2 | grep -v "^#" | sed 's/\r/\n/g' | xargs`

echo "Backup following partitions: ${PARTITIONS} to directory ${DIR}?"

for P in ${PARTITIONS}; do
    [ -f ${DIR}/${P}.img ] && echo "ERR: ${DIR}/${P}.img already exists for requested partition ${P}"
done
for P in ${PARTITIONS}; do
    [ -e /dev/block/bootdevice/by-name/${P} ] || echo "ERR: partition ${P} doesn't exist on bootdevice /dev/block/bootdevice/by-name/${P}"
done

echo "Use gzip to create backups?, Enter 'Y' or anything else to skip compression"
read COMP

echo "Create md5sums?, Enter 'Y' or anything else to skip md5sums"
read SUMS

echo "Enter 'Y' to continue or anything else to exit"
read A

if [ "${A}" != "Y" ] ; then
    echo "Nothing to do, bye-bye"
    exit 0
fi

cp $2 ${DIR}/partition_list.txt

for P in ${PARTITIONS}; do
    if [ -e /dev/block/bootdevice/by-name/${P} ] ; then
        DEV=`readlink /dev/block/bootdevice/by-name/${P}`
        PART=`basename ${DEV}`
        SIZE=`cat /sys/block/mmcblk0/${PART}/size`
        # from 512b blocks to kb
        SIZE=`expr ${SIZE} / 2`
        if [ "${SUMS}" = "Y" ] ; then
            echo "md5sum ${P}"
            md5sum /dev/block/bootdevice/by-name/${P} | tee ${DIR}/${P}.part.md5
        fi
        echo "Starting to backup partition ${P}, ${PART}, size ${SIZE}kb"
        echo "${SIZE}" > ${DIR}/${P}.part.size
        if [ "${COMP}" != "Y" ] ; then
            OUT=${DIR}/${P}.img
            dd if=/dev/block/bootdevice/by-name/${P} of=${OUT}
        else
            OUT=${DIR}/${P}.img.gz
            dd if=/dev/block/bootdevice/by-name/${P} | gzip > ${OUT}
        fi
        if [ "${SUMS}" = "Y" ] ; then
            echo "md5sum ${OUT}"
            md5sum ${OUT} | sed "s#${DIR}/##g" > ${OUT}.md5
            if [ "${COMP}" != "Y" ] ; then
                FILESIZE=`du -k ${OUT} | awk '{print $1}'`
                PARTSIZE=`cat ${DIR}/${P}.part.size`
                [ "${FILESIZE}" != "${PARTSIZE}" ] && echo "ERR: backup file size ${FILESIZE}kb doesn't match with partition size ${PARTSIZE}kb"
                FILESUM=`cat ${OUT}.md5 | awk '{print $1}'`
                PARTSUM=`cat ${DIR}/${P}.part.md5 | awk '{print $1}'`
                [ "${FILESUM}" != "${PARTSUM}" ] && echo "ERR: backup md5sum ${FILESUM} doesn't match with partition md5sum ${PARTSUM}"
            fi
        fi
    else
        echo "ERR: partition ${P} doesn't exist on bootdevice /dev/block/bootdevice/by-name/${P}"
    fi
done
if [ "${SUMS}" = "Y" ] ; then
    cat ${DIR}/*.img*.md5 > ${DIR}/md5sums
    cat ${DIR}/*.part.md5 > ${DIR}/md5sums.part
fi

echo "Calling sync to make sure all files are written"
sync
