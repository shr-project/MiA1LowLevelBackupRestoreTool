#!/sbin/sh

if [ $# -ne 2 ] ; then
    echo "Usage $0 directory-to-backup file-with-list-of-partitions-to-backup"
    exit 1
fi

if [ ! -d $1 ] ; then
    echo "First parameter '$1' isn't a directory"
    exit 2
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

echo "Enter 'Y' to continue or anything else to exit"
read A

if [ "${A}" != "Y" ] ; then
    echo "Nothing to do, bye-bye"
    exit 0
fi

for P in ${PARTITIONS}; do
    if [ -e /dev/block/bootdevice/by-name/${P} ] ; then
        dd if=/dev/block/bootdevice/by-name/${P} of=${DIR}/${P}.img
    else
        echo "ERR: partition ${P} doesn't exist on bootdevice /dev/block/bootdevice/by-name/${P}"
    fi
done

sync
