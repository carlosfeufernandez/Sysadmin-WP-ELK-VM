#!/bin/bash

apt-get -y update
apt-get -y install nginx mariadb-server mariadb-common php-fpm php-mysql expect php-curl php-gd php-intl php-mbstring php-soap php-xml php-xmlrpc php-zip

parted -s /dev/sdc mklabel gpt
parted -s -a optimal /dev/sdc mkpart logical 0% 100%
parted -s /dev/sdc 'set 1 lvm on'
pvcreate /dev/sdc1
vgcreate wp_vg /dev/sdc1
lvcreate -l 100%FREE wp_vg -n data_wp
mkfs.ext4 /dev/wp_vg/data_wp
mount /dev/wp_vg/data_wp /var/lib/mysql
printf '/dev/wp_vg/data_wp       /var/lib/wordpress  ext4    defaults        0       0' >> /etc/fstab
umount /var/lib/mysql
#shutdown -r now


