#!/bin/bash
ON=$(ifconfig | grep -cs 'vboxnet')

if [[ $ON == 1 ]]
then
  echo "Host only interface is up"
else 
VBoxManage hostonlyif create
VBoxManage hostonlyif ipconfig vboxnet0 --ip 192.168.56.1
fi

cd /etc/cuckoo-modified/utils/
rm -f /tmp/gitpull_output.txt
git pull > /tmp/gitpull_output.txt

if grep -Fxq "Already up-to-date" /tmp/gitpull_output.txt
then
echo "Signatures are up to date."
else
git pull
python /etc/cuckoo-modified/utils/community.py --force --all
fi

cd /etc/cuckoo-modified/web/
./manage.py migrate
./manage.py runserver 127.0.0.1:8000 &
cd ..
./cuckoo.py
