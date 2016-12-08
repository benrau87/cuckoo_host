#!/bin/bash
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'
gitdir=$PWD
echo -e "${YELLOW}What would you like your Cuckoo username to be?${NC}"
read name
adduser $name

##Add startup script to cuckoo users home folder
chmod +x start_cuckoo.sh
chown $name:$name start_cuckoo.sh
mv start_cuckoo.sh /home/$name/

##Start mongodb 
cp mongodb.service /etc/systemd/system/

##Create directories for later
cd /home/$name/
dir=$PWD
mkdir tools/
cd tools/

##Depos add
echo -e "${RED}Installing Dependencies...Please Wait${NC}"
#Mongodb
apt-key adv --keyserver keyserver.ubuntu.com --recv EA312927
echo "deb http://repo.mongodb.org/apt/ubuntu trusty/mongodb-org/3.2 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.2.list
##Holding pattern for dpkg...
echo "Waiting for dpkg process to free up..."
while fuser /var/lib/dpkg/lock >/dev/null 2>&1; do
   sleep 1
done
apt-get -qq update -y
apt-get -qq install wireshark mongodb-org=3.2.11 tcpdump virtualbox python python-pip python-dev libvirt-dev libffi-dev libssl-dev libxml2-dev libxslt1-dev libjpeg-dev libcap2-bin python-dnspython python-bson autoconf libtool libjansson-dev libmagic-dev libssl-dev -y
apt-get -qq dist-upgrade -y
pip install --upgrade pip
pip install -r $gitdir/requirements.txt
##Add user to vbox and enable mongodb
usermod -a -G vboxusers $name
systemctl start mongodb
sleep 10
systemctl enable mongodb

##tcpdump permissions
setcap cap_net_raw,cap_net_admin=eip /usr/sbin/tcpdump

##Yara
#apt-get install -qq autoconf libtool libjansson-dev libmagic-dev libssl-dev -y
wget https://github.com/plusvic/yara/archive/v3.4.0.tar.gz -O yara-3.4.0.tar.gz
tar -zxf yara-3.4.0.tar.gz
cd yara-3.4.0
./bootstrap.sh
./configure --with-crypto --enable-cuckoo --enable-magic
make 
make install
cd yara-python
python setup.py build
python setup.py install

##Pydeep
cd $dir/tools/
wget http://sourceforge.net/projects/ssdeep/files/ssdeep-2.13/ssdeep-2.13.tar.gz/download -O ssdeep-2.13.tar.gz
tar -zxf ssdeep-2.13.tar.gz
cd ssdeep-2.13
./configure
make 
make install
apt-get -qq install python-pip -y
pip install pydeep

##Volatility
cd $dir/tools/ 
git clone https://github.com/volatilityfoundation/volatility.git
cd volatility
python setup.py build
python setup.py install

##Other tools
cd $dir/tools/
git clone https://github.com/jpsenior/threataggregator.git
wget https://github.com/kevthehermit/VolUtility/archive/v1.0.tar.gz
git clone https://github.com/jbremer/vmcloak.git
tar -xvzf v1.0.tar.gz

##Cuckoo
cd /etc/
git clone https://github.com/spender-sandbox/cuckoo-modified.git
pip install -r cuckoo-modified/requirements.txt
pip install django-ratelimit
cd cuckoo-modified/utils/
python comm* --all --force

##Copy over conf files
cd $gitdir/
cp cuckoo.conf reporting.conf virtualbox.conf /etc/cuckoo-modified/conf/
##Add vmcloak scripts 
chmod +x vmcloak.sh
cp vmcloak.sh $dir/
##Add windows python and PIL installers for VMs
cd $dir
mkdir windows_python_exe/
cp /etc/cuckoo-modified/agent/agent.py $dir/windows_python_exe/
cd windows_python_exe/
wget http://effbot.org/downloads/PIL-1.1.7.win32-py2.7.exe
wget https://www.python.org/ftp/python/2.7.11/python-2.7.11.msi

##Change ownership for folder that have been created
chown -R $name:$name /home/$name/*
chown -R $name:$name /etc/cuckoo-modified/*
chmod -R 777 /etc/cuckoo-modified/

###Setup of VirtualBox forwarding rules and host only adapter
VBoxManage hostonlyif create
VBoxManage hostonlyif ipconfig vboxnet0 --ip 192.168.56.1
iptables -A FORWARD -o eth0 -i vboxnet0 -s 192.168.56.0/24 -m conntrack --ctstate NEW -j ACCEPT
sudo iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A POSTROUTING -t nat -j MASQUERADE
sudo sysctl -w net.ipv4.ip_forward=1

##Below can be enabled if using a external DB connection
#iptables -A INPUT -s 0.0.0.0 -p tcp --destination-port 27017 -m state --state NEW,ESTABLISHED -j ACCEPT
#iptables -A OUTPUT -d 0.0.0.0 -p tcp --source-port 27017 -m state --state ESTABLISHED -j ACCEPT

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
read -p "Would you like to create VMs at this time? Y/N" -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]
then
bash $dir/vmcloak.sh
fi
echo
echo -e "${YELLOW}Installation complete, login as $name and open the terminal. In $name home folder you will find the start_cuckoo script. To get started as fast as possible you will need to create a virtualbox vm and name it ${RED}cuckoo1${NC}.${YELLOW} Take a snapshot after it has been created and is running the agent and python 27. Name the snapshot ${RED}vmcloak${YELLOW}. Alternatively you can create the VM with the vmcloak.sh script provided in your home directory. This will require you have a local copy of the Windows ISO you wish to use. You can then launch cuckoo_start.sh and navigate to $HOSTNAME:8000${NC}"

