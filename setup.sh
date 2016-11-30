#!/bin/bash
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'
echo -e "${YELLOW}What would you like your Cuckoo username to be?${NC}"
read name
adduser $name

#Add startup script
chmod +x start_cuckoo.sh
#cp start_cuckoo.sh /etc/
#cp start.conf /etc/init/

cp *.conf /home/$name/
#cp mongodb.service /etc/systemd/system/
cp start_cuckoo.sh /home/$home/cuckoo/
cd /home/$name/
dir=$PWD
mkdir tools/
cd tools/
##Depos add
echo -e "${RED}Installing Dependencies...Please Wait${NC}"
#Mongodb
apt-key adv --keyserver keyserver.ubuntu.com --recv EA312927
echo "deb http://repo.mongodb.org/apt/ubuntu trusty/mongodb-org/3.2 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.2.list

echo "Waiting for dpkg process to free up..."
while fuser /var/lib/dpkg/lock >/dev/null 2>&1; do
   sleep 1
done

apt-get -qq update -y
apt-get -qq install wireshark mongodb-org=3.2.11 tcpdump virtualbox python python-pip python-dev libffi-dev libssl-dev libxml2-dev libxslt1-dev libjpeg-dev libcap2-bin python-dnspython -y
#apt-get -qq install python python-pip python-dev libffi-dev libssl-dev libxml2-dev libxslt1-dev libjpeg-dev mongodb virtualbox tcpdump wireshark -y
#apt-get install mongodb libffi-dev build-essential python-django python python-dev python-pip python-pil python-sqlalchemy python-bson python-dpkt python-jinja2 python-magic python-pymongo python-gridfs python-libvirt python-bottle python-pefile python-chardet tcpdump wireshark virtualbox -y
#apt-get -qq install python python-pip python-dev libcap2-bin libffi-dev libssl-dev libxml2-dev libxslt1-dev libjpeg-dev tcpdump mongodb virtualbox -y
#apt-get -qq install mongodb libffi-dev build-essential python-django python python-dev python-pip python-pil python-sqlalchemy python-bson python-dpkt python-jinja2 python-magic python-pymongo python-gridfs python-libvirt python-bottle python-pefile python-chardet virtualbox tcpdump -y
apt-get -qq dist-upgrade -y
pip install --upgrade pip
systemctl start mongodb
sleep 10
systemctl enable mongodb
#systemctl enable mongodb.service
##tcpdump permissions
setcap cap_net_raw,cap_net_admin=eip /usr/sbin/tcpdump

##Yara
apt-get install -qq autoconf libtool libjansson-dev libmagic-dev libssl-dev -y
wget https://github.com/plusvic/yara/archive/v3.4.0.tar.gz -O yara-3.4.0.tar.gz
tar -zxf yara-3.4.0.tar.gz
cd yara-3.4.0
./bootstrap.sh
./configure --with-crypto --enable-cuckoo --enable-magic
make && make install
cd yara-python
python setup.py build
python setup.py install

##Pydeep
cd $dir
wget http://sourceforge.net/projects/ssdeep/files/ssdeep-2.13/ssdeep-2.13.tar.gz/download -O ssdeep-2.13.tar.gz
tar -zxf ssdeep-2.13.tar.gz
cd ssdeep-2.13
./configure
make && make install
pip install pydeep

##Volatility
cd $dir
pip install openpyxl
pip install ujson
pip install pycrypto
pip install distorm3
pip install pytz 
git clone https://github.com/volatilityfoundation/volatility.git
cd volatility
python setup.py build
python setup.py install

##Cuckoo
cd $dir
usermod -a -G vboxusers $name
#git clone https://github.com/cuckoosandbox/cuckoo.git
git clone https://github.com/spender-sandbox/cuckoo-modified.git
wget https://downloads.cuckoosandbox.org/2.0-rc2/cuckoo-2.0-rc2.tar.gz
tar -xvzf cuckoo-2.0-rc2.tar.gz
pip install -r cuckoo/requirements.txt
pip install django-ratelimit
cp cuckoo.conf reporting.conf virtualbox.conf cuckoo/conf/
#rm *.conf
mkdir windows_python_exe/
cd windows_python_exe/
wget http://effbot.org/downloads/PIL-1.1.7.win32-py2.7.exe
wget https://www.python.org/ftp/python/2.7.11/python-2.7.11.msi
cd ..
cd cuckoo/utils/
python comm* --all --force
cd $dir/tools/
git clone https://github.com/jpsenior/threataggregator.git
wget https://github.com/kevthehermit/VolUtility/archive/v1.0.tar.gz
tar -xvzf v1.0.tar.gz

chown -R $name:$name /home/$name/*
#Create mongo database and make cuckoo user owner
mkdir /data
mkdir /data/db

chown -R $name:$name /data/*
###Setup of VirtualBox forwarding rules and host only adapter
vboxmanage hostonlyif create
iptables -A FORWARD -o eth0 -i vboxnet0 -s 192.168.56.0/24 -m conntrack --ctstate NEW -j ACCEPT
sudo iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A POSTROUTING -t nat -j MASQUERADE
sudo sysctl -w net.ipv4.ip_forward=1
iptables -A INPUT -s 0.0.0.0 -p tcp --destination-port 27017 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -d 0.0.0.0 -p tcp --source-port 27017 -m state --state ESTABLISHED -j ACCEPT

echo "Waiting for dpkg process to free up..."
while fuser /var/lib/dpkg/lock >/dev/null 2>&1; do
   sleep 1
done

echo
read -p "Do you want to iptable changes persistent? Y/N" -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]
then
apt-get -qq install iptables-persistent -y
fi
echo
echo -e "${YELLOW}Installation complete, login as $name and open the terminal. In $name home folder you will find the cuckoo client. To get started as fast as possible you will need to create a virtualbox vm and name it ${RED}Win7 Clone${NC}.${YELLOW} Take a snapshot after it has been created and is running the agent and python 27. You can then launch cuckoo_start.sh and navigate to $HOSTNAME:8000${NC}"

