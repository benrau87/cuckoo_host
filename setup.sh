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
cp start_cuckoo.sh /etc/
cp start.conf /etc/init/

cp *.conf /home/$name/
cd /home/$name/
dir=$PWD
##Depos add
echo -e "${RED}Installing Dependencies...Please Wait${NC}"
apt-get -qq update -y
apt-get -qq dist-upgrade -y
apt-get -qq install wireshark tcpdump python python-pip python-dev libffi-dev libssl-dev libxml2-dev libxslt1-dev libjpeg-dev mongodb -y
#apt-get -qq install python python-pip python-dev libffi-dev libssl-dev libxml2-dev libxslt1-dev libjpeg-dev mongodb virtualbox tcpdump wireshark -y
#apt-get install mongodb libffi-dev build-essential python-django python python-dev python-pip python-pil python-sqlalchemy python-bson python-dpkt python-jinja2 python-magic python-pymongo python-gridfs python-libvirt python-bottle python-pefile python-chardet tcpdump wireshark virtualbox -y
#apt-get -qq install python python-pip python-dev libcap2-bin libffi-dev libssl-dev libxml2-dev libxslt1-dev libjpeg-dev tcpdump mongodb virtualbox -y
#apt-get -qq install mongodb libffi-dev build-essential python-django python python-dev python-pip python-pil python-sqlalchemy python-bson python-dpkt python-jinja2 python-magic python-pymongo python-gridfs python-libvirt python-bottle python-pefile python-chardet virtualbox tcpdump -y
pip install --upgrade pip

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
cd /home/$name/
usermod -a -G vboxusers $name
#git clone https://github.com/cuckoosandbox/cuckoo.git
wget https://downloads.cuckoosandbox.org/2.0-rc2/cuckoo-2.0-rc2.tar.gz
tar -xvzf cuckoo-2.0-rc2.tar.gz
pip install -r cuckoo/requirements.txt
chown -R $name:$name /home/$name/*

mkdir windows_python_exe/
cd windows_python_exe/
wget http://effbot.org/downloads/PIL-1.1.7.win32-py2.7.exe
wget https://www.python.org/ftp/python/2.7.11/python-2.7.11.amd64.msi
cd ..
cd cuckoo/utils/
python comm* --all --force
cd ..
wget https://github.com/kevthehermit/VolUtility/archive/v1.0.tar.gz
tar -xvzf v1.0.tar.gz

###Setup of VirtualBox forwarding rules and host only adapter
vboxmanage hostonlyif create
iptables -A FORWARD -o eth0 -i vboxnet0 -s 192.168.56.0/24 -m conntrack --ctstate NEW -j ACCEPT
sudo iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A POSTROUTING -t nat -j MASQUERADE
sudo sysctl -w net.ipv4.ip_forward=1

echo
echo -e "${YELLOW}Installation complete, login as $name and open the terminal. In the cuckoo folder under ~, you can launch start_sever.sh to share agent and exe's. Report webpage is at http://localhost:8000${NC}"
