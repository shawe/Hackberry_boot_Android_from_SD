#!/bin/bash

# Based on:
#   http://linux-sunxi.org/Boot_Android_from_SdCard#BootLoader
#   http://jas-hacks.blogspot.co.uk/2012/12/hackberry-a10-booting-android-from-sd.html
#	http://tmerle.blogspot.fr/2012/11/booting-android-ics-system-from-sdcard.html

card=/dev/sdb
echo "Downloading required files..."
wget -c https://github.com/linux-sunxi/sunxi-bin-archive/raw/master/hackberry/stock-nanda-1gb/script.bin
wget -c http://dl.miniand.com/jas-hacks/uboot/1gb/sunxi-spl.bin
wget -c http://dl.miniand.com/jas-hacks/uboot/1gb/u-boot.bin
wget -c http://dl.linux-sunxi.org/users/arete74/tools.tar.gz
#wget -c boot-CM.tar
#wget -c recovery-CM.tar
#wget -c system-CM.tar
tar -zxvf tools.tar.gz
git clone https://github.com/Ithamar/awutils.git
cd awutils
make
cd ..
cp awutils/awimage tools/

echo "Require manually partition of SD card before continue"
echo "Edit this file for more details"
exit 0 #Comment this line when your SD card was with this

#	Partition		Filesystem		Label			Size					Internal NAND
#	unallocated		unallocated						17MB
#	/dev/sdb1		fat16			bootloader		16MB					nanda
#	/dev/sdb2		ext4			environment		16MB					nandb
#	/dev/sdb3		ext4			boot			32MB					nandc
#	/dev/sdb4		extended						fill all space
#	/dev/sdb5		ext4			system			512MB					nandd
#	/dev/sdb6		ext4			data			1024MB					nande
#	/dev/sdb7		ext4			misc			16MB					nandf
#	/dev/sdb8		ext4			recovery		32MB					nandg
#	/dev/sdb9		ext4			cache			256MB					nandh
#	/dev/sdb10		ext4			private			32MB					nandi
#	/dev/sdb11		ext4			sysrecovery		512MB					nandj
#	/dev/sdb12		ext4			UDISK			2048MB					nandk
#	/dev/sdb13		ext4			extsd			all available space

## DON'T UNCOMMENT THIS LINES !!!

#echo "Destroying TOC ${card}"
#dd if=/dev/zero of=$card bs=1M count=1
#sync
#partprobe

#echo "Destroying any old uboot environment ${card}"
#dd if=/dev/zero of=$card bs=512 count=2047
#sync
#partprobe

#echo "Partitionning ${card}"
#dd if=/dev/zero of=$card bs=512 count=1
#sync
#/sbin/sfdisk -R $card
#cat <<EOT | sfdisk --in-order -uM $card
#17,16,c
#,16,83
#,32,83
#,,5
#,512,83
#,1024,83
#,16,83
#,32,83
#,256,83
#,16,c
#,512,83
#,2048,83
#,,83
#EOT
#sync
#partprobe

for i in {1..13}
do
   umount ${card}${i}
done

echo "Formatting partitions of ${card}"
echo "Formatting ${card}1 bootloader"
mkfs.vfat -n bootloader ${card}1
echo "Formatting ${card}2"
mkfs.ext4 -L env		${card}2
echo "Formatting ${card}3 boot"
mkfs.ext4 -L boot       ${card}3
echo "Formatting ${card}5 system"
mkfs.ext4 -L system     ${card}5
echo "Formatting ${card}6 data"
mkfs.ext4 -L data       ${card}6
echo "Formatting ${card}7 misc"
mkfs.ext4 -L misc       ${card}7
echo "Formatting ${card}8 recovery"
mkfs.ext4 -L recovery   ${card}8
echo "Formatting ${card}9 cache"
mkfs.ext4 -L cache      ${card}9
echo "Formatting ${card}10 private"
mkfs.vfat -n private    ${card}10
echo "Formatting ${card}11 sysrecovery"
mkfs.ext4 -L sysrecovery ${card}11
echo "Formatting ${card}12 UDISK"
mkfs.vfat -n UDISK      ${card}12
echo "Formatting ${card}13 extsd"
mkfs.vfat -n extsd      ${card}13

echo "Deleting huge files"
tune2fs -O ^huge_file ${card}1
tune2fs -O ^huge_file ${card}2
tune2fs -O ^huge_file ${card}3
tune2fs -O ^huge_file ${card}5
tune2fs -O ^huge_file ${card}6
tune2fs -O ^huge_file ${card}7
tune2fs -O ^huge_file ${card}8
tune2fs -O ^huge_file ${card}9
tune2fs -O ^huge_file ${card}10
tune2fs -O ^huge_file ${card}11
tune2fs -O ^huge_file ${card}12
tune2fs -O ^huge_file ${card}13

echo "Checking integrity of ${card}"
fsck.vfat -a ${card}1
fsck.ext4 -p ${card}2
fsck.ext4 -p ${card}3
fsck.ext4 -p ${card}5
fsck.ext4 -p ${card}6
fsck.ext4 -p ${card}7
fsck.ext4 -p ${card}8
fsck.ext4 -p ${card}9
fsck.vfat -a ${card}10
fsck.ext4 -p ${card}11
fsck.vfat -a ${card}12
fsck.vfat -a ${card}13

echo "Flashing sunxi-spl to ${card}"
dd if=sunxi-spl.bin of=$card bs=1024 seek=8
sync
echo "Flashing u-boot to ${card}"
dd if=u-boot.bin of=$card bs=1024 seek=32
sync

echo "Preparing ${card}1"
mount ${card}1 /mnt/ || exit 0
cp uImage  /mnt
cp script.bin /mnt
cp boot.scr /mnt
cat >/mnt/uEnv.txt << EOT
fexfile=script.bin
kernel=uImage
extraargs=root=/dev/mmcblk0p3 loglevel=8 rootwait console=ttyS0,115200 rw init=/init mac_addr=00:AE:99:A3:E4:AF
boot_mmc=fatload mmc 0 0x43000000 ${fexfile}; fatload mmc 0 0x48000000 ${kernel}; bootm 0x48000000
EOT
cat >/mnt/uEnv_recovery.txt << EOT
fexfile=script.bin
kernel=uImage
extraargs=root=/dev/mmcblk0p8 loglevel=8 rootwait console=ttyS0,115200 rw init=/init mac_addr=00:AE:99:A3:E4:AF
boot_mmc=fatload mmc 0 0x43000000 ${fexfile}; fatload mmc 0 0x48000000 ${kernel}; bootm 0x48000000
EOT
sync
umount /mnt

echo "Preparing ${card}3"
mount ${card}3 /mnt || exit 0
tar -xpf boot-CM.tar -C /mnt
sed -i "s/nandc/mmcblk0p3/g"  /mnt/init.sun4i.rc
sed -i "s/nandd/mmcblk0p5/g"  /mnt/init.sun4i.rc
sed -i "s/nande/mmcblk0p6/g"  /mnt/init.sun4i.rc
sed -i "s/nandf/mmcblk0p7/g"  /mnt/init.sun4i.rc
sed -i "s/nandg/mmcblk0p8/g"  /mnt/init.sun4i.rc
sed -i "s/nandh/mmcblk0p9/g"  /mnt/init.sun4i.rc
sed -i "s/nandi/mmcblk0p10/g" /mnt/init.sun4i.rc
sync
umount /mnt

echo "Preparing ${card}5"
mount ${card}5 /mnt || exit 0
tar -xpf system-CM.tar -C /mnt
sed -i "s/\/devices\/virtual\/block\/nandi/\/devices\/virtual\/block\/mmcblk0p10/g"  /mnt/etc/vold.fstab
sed -i "s/\/devices\/platform\/sunxi-mmc.0\/mmc_host/\/devices\/virtual\/block\/mmcblk0p13/g"  /mnt/etc/vold.fstab
sync
umount /mnt

echo "Preparing ${card}8"
mount ${card}8 /mnt || exit 0
tar -xpf recovery-CM.tar -C /mnt
sed -i "s/nandf/mmcblk0p7/g"  /mnt/ueventd.sun4i.rc
sync
umount /mnt
