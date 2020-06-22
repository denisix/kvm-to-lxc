#!/bin/sh
TMP=/root/.tmp
VM=$1

if [ "$VM" = "" ]
then
	echo "Usage: kvm-to-lxc <VM name/ID>"
	exit 0
fi

QCOW=$(virsh dumpxml $VM|awk -F\' '/source file/{print $2}')
MAC=$(virsh dumpxml $VM|awk -F\' '/mac address/{print $2}')

if [ "$QCOW" = "" ]
then
	echo "- qcow2 not found, check dumpxml of vm"
	exit 0
fi

echo "- mounting qcow2 - $QCOW"
lsmod | grep -q nbd || modprobe nbd max_part=63
qemu-nbd -c /dev/nbd0 $QCOW

echo "- fdisk list partions:"
fdisk -l /dev/nbd0

LP=$(fdisk -l /dev/nbd0|awk '/G/{if (/Linux/) print $1}')
echo "- linux partition detected -> $LP"

echo "- mounting partition.."
[ -x "$TMP" ] || mkdir $TMP
mount | grep -q $TMP && umount $TMP

mount $LP $TMP
SRC=$TMP
OK=$(mount|grep $LP)
echo "- mounted: $OK"

LXCROOT=$(lxc storage ls --format yaml|awk '/source:/{print $2}')
echo "- LXC root storage: $LXCROOT"

ROOT=$LXCROOT/containers/$VM/rootfs/

echo "- check source OS version: "
cat $SRC/etc/os-release

OS=$(awk -F\= '/^ID=/{print $2}' $SRC/etc/os-release)
OSVER=$(awk -F\= '/VERSION_CODENAME=/{print $2}' $SRC/etc/os-release)

echo "- OS: [$OS] VER: [$OSVER]"
echo "- find LXC container with the same name - $VM"
lxc ls | grep $VM || lxc launch images:$OS/$OSVER $VM || ( echo "Cant lauch LXC with image: $OS/$OSVER"; exit 0 )

lxc stop $VM
lxc config set $VM volatile.eth0.hwaddr $MAC

echo "- sync.."
rsync -ap --numeric-ids --delete /$SRC/ $ROOT/

echo "- synced, fixing /dev/.."
DEV=${ROOT}/dev
mv ${DEV} ${DEV}.old
mkdir -p ${DEV}
mknod -m 666 ${DEV}/null c 1 3
mknod -m 666 ${DEV}/zero c 1 5
mknod -m 666 ${DEV}/random c 1 8
mknod -m 666 ${DEV}/urandom c 1 9
mkdir -m 755 ${DEV}/pts
mkdir -m 1777 ${DEV}/shm
mknod -m 666 ${DEV}/tty c 5 0
mknod -m 600 ${DEV}/console c 5 1
mknod -m 666 ${DEV}/tty0 c 4 0
mknod -m 666 ${DEV}/tty1 c 4 1
mknod -m 666 ${DEV}/tty2 c 4 2
mknod -m 666 ${DEV}/tty3 c 4 3
mknod -m 666 ${DEV}/tty4 c 4 4
mknod -m 666 ${DEV}/tty5 c 4 5
mknod -m 666 ${DEV}/tty6 c 4 6
mknod -m 666 ${DEV}/full c 1 7
mknod -m 600 ${DEV}/initctl p
mknod -m 666 ${DEV}/ptmx c 5 2

echo "- fix perms: UID"
starting_uid=1000000
for uid in `cat $ROOT/etc/passwd | cut -d : -f 3`; do
    echo $newuid
    newuid=$(($uid + $starting_uid))
    find $ROOT -uid $uid -exec chown -h $newuid {} +
done

echo "- fix perms: GID"
starting_gid=1000000
for gid in `cat $ROOT/etc/passwd | cut -d : -f 4`; do
    newgid=$(($gid + $starting_gid))
    find $ROOT -gid $gid -exec chgrp -h $newgid {} +
done

echo "- unmount qcow.."
umount $SRC
losetup -d /dev/loop0
qemu-nbd -d /dev/nbd0
rmmod nbd

echo "- done, stating vm: $VM"
lxc start $VM
lxc ls | grep $VM
