#!/bin/bash
apt-get install mkisofs genisoimage -y
sudo mkdir -p /mnt/windows_ISOs
##VMCloak
echo
read -p "Please place your Windows ISO in the folder under /mnt/windows_ISOs and enter Y to continue" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
pip install vmcloak --upgrade
mount -o loop,ro *.iso /mnt/windows_ISOs 
vmcloak-vboxnet0
vmcloak init --win7x86 --iso-mount /mnt/windows_ISOs/ seven0

vmcloak install seven0 adobe9 wic pillow dotnet40 java7

#vmcloak install seven0 office2007 \
#    office2007.isopath=/path/to/a.iso \
#    office2007.serialkey=ABC-DEF

vmcloak snapshot seven0 cuckoo1 192.168.56.101
fi
