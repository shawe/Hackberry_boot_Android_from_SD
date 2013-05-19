setenv setargs 'setenv bootargs console=ttyS0,115200 root=/dev/mmcblk0p3 loglevel=8 panic=10 rootfstype=ext4 rootwait rw init=/init'
setenv boot_mmc 'fatload mmc 0 0x43000000 script.bin; fatload mmc 0 0x48000000 uImage; bootm 0x48000000'
setenv bootcmd 'run setargs boot_mmc'
