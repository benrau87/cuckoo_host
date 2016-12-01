#!/bin/bash
apt-get install mkisofs genisoimage -y
sudo mkdir -p ~/Desktop/windows_ISOs
##VMCloak
echo
read -p "Please place your Windows ISO in the folder on your deskotp and enter Y to continue" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
pip install vmcloak --upgrade
mount -o loop,ro *.iso ~/Desktop/windows_ISOs 
vmcloak-vboxnet0
vmcloak -r --win7x32 win7vm
fi
