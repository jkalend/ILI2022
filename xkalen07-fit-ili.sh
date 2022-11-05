#!/bin/bash

echo "Creating 4 loop devices"
for i in $(seq 0 3)
do
    echo "..c reating loop device /dev/loop$i"
    dd if=/dev/zero of=~/file"${i}".img bs=1MiB count=200
    losetup /dev/loop"${i}" ~/file"${i}".img
done

echo "2) Creating RAID1 and RAID0"
mdadm --create /dev/md1 --level=mirror --raid-devices=2 /dev/loop0 /dev/loop1
mdadm --create /dev/md0 --level=mirror --raid-devices=2 /dev/loop2 /dev/loop3

echo "3) Creating physical volume FIT_vg"
pvcreate /dev/md0
pvcreate /dev/md1
vgcreate FIT_vg /dev/md0 /dev/md1

echo "4) Creating logical volumes FIT_1v1 and FIT_1v2"
lvcreate -n FIT_lv1 -L 100M FIT_vg
lvcreate -n FIT_lv2 -L 100M FIT_vg

echo "5) Creating EXT4 filesystem"
mkfs.ext4 /dev/FIT_vg/FIT_lv1

echo "6) Creating XFS filesystem"
mkfs.xfs /dev/FIT_vg/FIT_lv2

echo "7) Mounting filesystems"
mkdir -p /mnt/test1
mkdir -p /mnt/test2
mount /dev/FIT_vg/FIT_lv1 /mnt/test1
mount /dev/FIT_vg/FIT_lv2 /mnt/test2

echo "8) Resize the first filesystem"
umount /mnt/test1
lvextend -L +100M /dev/FIT_vg/FIT_lv1
resize2fs /dev/FIT_vg/FIT_lv1
mount /dev/FIT_vg/FIT_lv1 /mnt/test1

echo "9) Create big_file"
dd if=/dev/urandom of=/mnt/test1/big_file bs=1M count=300
md512sum /mnt/test1/big_file

echo "10) Emulate faulty disk"
dd if=/dev/zero of=~/loop4 bs=1M count=200
losetup /dev/loop4 ~/loop04
mdadm --manage /dev/md0 --fail /dev/loop2
mdadm --manage /dev/md0 --remove /dev/loop2
mdadm --manage /dev/md0 --add /dev/loop4
