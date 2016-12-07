#!/bin/bash
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

apt-get install mkisofs genisoimage -y
sudo mkdir -p /mnt/windows_ISOs
##VMCloak
echo
read -p "Please place your Windows ISO in the folder under /mnt/windows_ISOs and enter Y to continue" -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]
then
pip install vmcloak --upgrade
mount -o loop,ro  --source /mnt/windows_ISOs/*.iso --target /mnt/windows_ISOs/
vmcloak-vboxnet0
echo -e "${YELLOW}###################################${NC}"
echo -e "${YELLOW}This process will take some time, you should get a sandwich, or watch the install if you'd like...${NC}"
echo
sleep 5
vmcloak init --vm-visible --win7x86 --iso-mount /mnt/windows_ISOs/ seven0
vmcloak install seven0 adobe9 wic pillow dotnet40 java7
fi

echo
read -p "Would you like to install Office 2007? This WILL require an ISO and key. Y/N" -n 1 -r
  if [[ $REPLY =~ ^[Yy]$ ]]
  then
  echo
  echo -e "${YELLOW}What is the path to the iso?${NC}"
  read path
  echo
  echo -e "${YELLOW}What is the license key?${NC}"
  read key
  vmcloak install seven0 office2007 \
    office2007.isopath=$path \
    office2007.serialkey=$key
  fi
echo -e "${YELLOW}Creating snapshot of VM${NC}"  
vmcloak snapshot seven0 cuckoo1 192.168.56.2
echo -e "${YELLOW}What is your cuckoo user account name?${NC}"
read user
chown -R $user:$user ~/.vmcloak


