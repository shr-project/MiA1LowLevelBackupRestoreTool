#!/sbin/sh

if [ $# -ne 2 ] ; then
    echo "Usage $0 directory-to-restore file-with-list-of-partitions-to-restore"
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

echo "Restore following partitions: ${PARTITIONS} from directory ${DIR}?"

for P in ${PARTITIONS}; do
    [ -e /dev/block/bootdevice/by-name/${P} ] || echo "ERR: partition ${P} doesn't exist on bootdevice /dev/block/bootdevice/by-name/${P}"
done
for P in ${PARTITIONS}; do
    [ -f ${DIR}/${P}.img ] || echo "ERR: ${DIR}/${P}.img doesn't exist for requested partition ${P}"
done
for P in `ls ${DIR}/*img | sed 's#.*/##g; s#\.img##g'`; do
    cat $2 | grep -v "^#" | sed 's/\r/\n/g' | grep -q "^${P}$" || echo "WARN: Skipping ${DIR}/${P}.img"
done

echo "Enter 'Y' to continue or anything else to exit"
read A

if [ "${A}" != "Y" ] ; then
    echo "Nothing to do, bye-bye"
    exit 0
fi

for P in ${PARTITIONS}; do
    if [ -f ${DIR}/${P}.img -a -e /dev/block/bootdevice/by-name/${P} ] ; then
        dd if=${DIR}/${P}.img of=/dev/block/bootdevice/by-name/${P}
    elif [ ! -f ${DIR}/${P}.img ] ; then
        echo "ERR: ${DIR}/${P}.img doesn't exist for requested partition ${P}"
    else
        echo "ERR: partition ${P} doesn't exist on bootdevice /dev/block/bootdevice/by-name/${P}"
    fi
done

sync
