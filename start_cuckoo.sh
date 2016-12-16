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
git checkout > /tmp/gitpull_output.txt

if grep -Fxq "Your branch is behind" /tmp/gitpull_output.txt
then
echo "Your branch is behind, you may think of updating with git pull."
else
echo "You are up to date."
fi

python /etc/cuckoo-modified/utils/community.py --force --all
cd /etc/cuckoo-modified/web/
./manage.py migrate
./manage.py runserver 127.0.0.1:8000 &
cd ..
./cuckoo.py
