#!/sbin/sh

if [ $# -ne 2 -a $# -ne 1 ] ; then
    echo "Usage $0 directory-to-restore [file-with-list-of-partitions-to-restore]"
    exit 1
fi

if [ ! -d $1 ] ; then
    echo "First parameter '$1' isn't a directory"
    exit 2
fi
if [ $# -eq 1 ] ; then
    LIST=$1/partition_list.txt
    if [ ! -f "${LIST}" ] ; then
        echo "Default list $1/partition_list.txt doesn't exist, you need to provide 2nd parameter with the list of partitions"
        exit 3
    fi
else
    LIST=$2
    if [ ! -f "${LIST}" ] ; then
        echo "Second parameter '${LIST}' isn't a file with list of partitions to restore"
        exit 4
    fi
fi

DIR=`echo $1 | sed 's#/$##'`
PARTITIONS=`cat ${LIST} | grep -v "^#" | sed 's/\r/\n/g' | xargs`

echo "Restore following partitions: ${PARTITIONS} from directory ${DIR}?"

for P in ${PARTITIONS}; do
    [ -e /dev/block/bootdevice/by-name/${P} ] || echo "ERR: partition ${P} doesn't exist on bootdevice /dev/block/bootdevice/by-name/${P}"
done
for P in ${PARTITIONS}; do
    [ -f ${DIR}/${P}.img -o -f ${DIR}/${P}.img.gz ] || echo "ERR: ${DIR}/${P}.img(.gz) doesn't exist for requested partition ${P}"
done
for P in `ls ${DIR}/*img ${DIR}/*img.gz 2>/dev/null | sed 's#.*/##g; s#\.gz##g; s#\.img##g'`; do
    cat ${LIST} | grep -v "^#" | sed 's/\r/\n/g' | grep -q "^${P}$" || echo "WARN: Skipping ${DIR}/${P}.img"
done

echo "Check checksums after restore? And skip identical partitions? Enter 'Y' to continue or anything else to exit"
read SUMS

echo "Enter 'Y' to continue or anything else to exit"
read A

if [ "${A}" != "Y" ] ; then
    echo "Nothing to do, bye-bye"
    exit 0
fi

for P in ${PARTITIONS}; do
    if [ ! -f ${DIR}/${P}.img -a ! -f ${DIR}/${P}.img.gz ] ; then
        echo "ERR: ${DIR}/${P}.img(.gz) doesn't exist for requested partition ${P}"
    elif [ -e /dev/block/bootdevice/by-name/${P} ] ; then
        DEV=`readlink /dev/block/bootdevice/by-name/${P}`
        PART=`basename ${DEV}`
        SIZE=`cat /sys/block/mmcblk0/${PART}/size`
        # from 512b blocks to kb
        SIZE=`expr ${SIZE} / 2`
        IN=${DIR}/${P}.img
        if [ ! -f ${IN} ] ; then
            IN=${IN}.gz
            COMP=Y
        fi
        if [ "${COMP}" != "Y" ] ; then
            FILESIZE=`du -k ${IN} | awk '{print $1}'`
            PARTSIZE=`cat ${DIR}/${P}.part.size`
            [ "${FILESIZE}" != "${PARTSIZE}" ] && echo "ERR: ${P} backup file size ${FILESIZE}kb doesn't match with stored partition size ${PARTSIZE}kb, press ENTER to continue" && read
            [ "${SIZE}" != "${PARTSIZE}" ] && echo "ERR: current ${P} partition size ${SIZE}kb doesn't match with stored partition size ${PARTSIZE}kb, press ENTER to continue" && read
            FILESUM=`md5sum ${IN} | awk '{print $1}'`
            PARTSUM=`cat ${IN}.md5 | awk '{print $1}'`
            [ "${FILESUM}" != "${PARTSUM}" ] && echo "ERR: ${P} backup md5sum ${FILESUM} doesn't match with stored md5sum ${PARTSUM}, press ENTER to continue" && read
        fi
        if [ "${SUMS}" = "Y" ] ; then
            PARTSUM=`md5sum /dev/block/bootdevice/by-name/${P} | awk '{print $1}'`
            SAVEDSUM=`cat ${DIR}/${P}.part.md5 | awk '{print $1}'`
            [ "${FILESUM}" = "${PARTSUM}" ] && echo "md5 for partition ${P} is identical in backup and the device, skipping this partition" && continue
        fi
        echo "Starting to restore partition ${P}, ${PART}, size ${SIZE}kb"
        if [ "${COMP}" != "Y" ] ; then
            dd if=${IN} of=/dev/block/bootdevice/by-name/${P}
        else
            gzip -cd ${IN} | dd of=/dev/block/bootdevice/by-name/${P}
        fi
    elif [ ! -f ${DIR}/${P}.img -a ! -f ${DIR}/${P}.img.gz ] ; then
        echo "ERR: ${DIR}/${P}.img doesn't exist for requested partition ${P}"
    else
        echo "ERR: partition ${P} doesn't exist on bootdevice /dev/block/bootdevice/by-name/${P}"
    fi
done
if [ "${SUMS}" = "Y" -a -f "${DIR}/md5sums.part" ] ; then
    echo "Testing the md5sums from ${DIR}/md5sums.part"
    md5sum -c ${DIR}/md5sums.part
fi

echo "Calling sync to make sure all files are written"
sync
