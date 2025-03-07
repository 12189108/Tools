#!/bin/bash
#
# kpartx and qumu-utils are required
apt install cron kpartx qemu-utils -y
# get valid loop device
loopDevice=$(echo $(losetup -f))
loopDeviceNum=$(echo $(losetup -f) | cut -d'/' -f 3)
websiteDir="/www/wwwroot/cloud-images.a.disk.re/Ubuntu"

for distName in "jammy" "focal"; do
  for archVer in "amd64" "arm64"; do
    fileName="$distName-server-cloudimg-$archVer"
    wget --no-check-certificate -qO /root/$fileName.img "https://cloud-images.ubuntu.com/$distName/current/$fileName.img"
    qemu-img convert -f qcow2 -O raw /root/$fileName.img /root/$fileName.raw
    losetup $loopDevice /root/$fileName.raw
    mapperDevice=$(kpartx -av $loopDevice | grep "$loopDeviceNum" | head -n 1 | awk '{print $3}')
    mount /dev/mapper/$mapperDevice /mnt
    sed -ri 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="net.ifnames=0 biosdevname=0"/g' /mnt/etc/default/grub
    sed -ri 's/cloudimg-rootfs ro/cloudimg-rootfs ro net.ifnames=0 biosdevname=0/g' /mnt/boot/grub/grub.cfg
    umount /mnt
    kpartx -dv $loopDevice
    losetup -d $loopDevice
    rm -rf $websiteDir/$fileName.raw
    mv /root/$fileName.raw $websiteDir/$fileName.raw
    rm -rf /root/$fileName.img
  done
done

# write crontab task
if [[ ! `grep -i "autorepackimages" /etc/crontab` ]]; then
  sed -i '$i 30 4    * * 0   root    bash /root/autoRepackImages.sh' /etc/crontab
  /etc/init.d/cron restart
fi
