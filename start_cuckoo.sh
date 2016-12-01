#!/bin/bash
ON=$(ifconfig | grep -cs 'vboxnet')

if [[ $ON == 1 ]]
then
  echo "Host only interface is up"
else 
VBoxManage hostonlyif create
VBoxManage hostonlyif ipconfig vboxnet0 --ip 192.168.56.1
fi
#VBoxManage startvm --type headless 'Win7 Clone'
cd cuckoo/web/
./manage.py migrate
./manage.py runserver 0.0.0.0:8000 &
cd ..
./cuckoo.py
