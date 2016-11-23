#!/bin/bash
ON=$(ifconfig | grep -cs 'vboxnet')

if [[ $ON == 1 ]]
then
  echo "Host only interface is up"
else 
  vboxmanage hostonlyif create
fi

VBoxManage startvm --type headless 'Win7 Clone'
cd cuckoo/web/
./manage.py runserver 0.0.0.0:8000 &
cd ..
./cuckoo.py
