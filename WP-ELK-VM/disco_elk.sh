# Particionado discos

parted -s /dev/sdc mklabel gpt
parted -s -a optimal /dev/sdc mkpart logical 0% 100%
parted -s /dev/sdc 'set 1 lvm on'
pvcreate /dev/sdc1
vgcreate elk_vg /dev/sdc1
lvcreate -l 100%FREE elk_vg -n data_elk
mkfs.ext4 /dev/elk_vg/data_elk
mount /dev/elk_vg/data_elk /var/lib/elasticsearch
printf '/dev/elk_vg/data_elk       /var/lib/elasticsearch  ext4    defaults        0       0' >> /etc/fstab
umount /var/lib/elasticsearch
#shutdown -r now