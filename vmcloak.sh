#!/bin/bash
apt-get install mkisofs genisoimage -y
sudo mkdir -p /mnt/windows_ISOs
##VMCloak
echo
read -p "Please place your Windows ISO in the folder on your deskotp and enter Y to continue" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
pip install vmcloak --upgrade
mount -o loop,ro *.iso /mnt/windows_ISOs 
vmcloak-vboxnet0
vmcloak init --win7x64 seven0
fi
