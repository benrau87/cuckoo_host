#!/bin/bash
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'
gitdir=$PWD

# Logging setup. Ganked this entirely from stack overflow. Uses FIFO/pipe magic to log all the output of the script to a file. Also capable of accepting redirects/appends to the file for logging compiler stuff (configure, make and make install) to a log file instead of losing it on a screen buffer. This gives the user cleaner output, while logging everything in the background, for troubleshooting, analysis, or sending it to me for help.

logfile=/var/log/cuckoo_install.log
mkfifo ${logfile}.pipe
tee < ${logfile}.pipe $logfile &
exec &> ${logfile}.pipe
rm ${logfile}.pipe

#Functions, functions everywhere.
########################################
#metasploit-like print statements. Gratuitously ganked from  Darkoperator's metasploit install script. status messages, error messages, good status returns. I added in a notification print for areas users should definitely pay attention to.

function print_status ()
{
    echo -e "\x1B[01;34m[*]\x1B[0m $1"
}

function print_good ()
{
    echo -e "\x1B[01;32m[*]\x1B[0m $1"
}

function print_error ()
{
    echo -e "\x1B[01;31m[*]\x1B[0m $1"
}

function print_notification ()
{
	echo -e "\x1B[01;33m[*]\x1B[0m $1"
}

########################################
#Script does a lot of error checking. Decided to insert an error check function. If a task performed returns a non zero status code, something very likely went wrong.

function error_check
{

if [ $? -eq 0 ]; then
	print_good "$1 successfully completed."
else
	print_error "$1 failed. Please check $logfile for more details."
exit 1
fi

}

########################################
#Package installation function.

function install_packages()
{

apt-get update &>> $logfile && apt-get install -y ${@} &>> $logfile
error_check 'Package installation'

}

########################################
#This script creates a lot of directories by default. This is a function that checks if a directory already exists and if it doesn't creates the directory (including parent dirs if they're missing).

function dir_check()
{

if [ ! -d $1 ]; then
	print_notification "$1 does not exist. Creating.."
	mkdir -p $1
else
	print_notification "$1 already exists. (No problem, We'll use it anyhow)"
fi

}

########################################
##BEGIN MAIN SCRIPT##
#Pre checks: These are a couple of basic sanity checks the script does before proceeding.

print_status "OS Version Check.."
release=`lsb_release -r|awk '{print $2}'`
if [[ $release == "16."* ]]; then
	print_good "OS is Ubuntu. Good to go."
else
    print_notification "This is not Ubuntu 16.x, this autosnort script has NOT been tested on other platforms."
	print_notification "You continue at your own risk!(Please report your successes or failures!)"
fi

##Cuckoo user account
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
#this is a nice little hack I found in stack exchange to suppress messages during package installation.
export DEBIAN_FRONTEND=noninteractive
echo
print_status "${YELLOW}Installing Dependencies...Please Wait${NC}"
#Mongodb
apt-key adv --keyserver keyserver.ubuntu.com --recv EA312927
echo "deb http://repo.mongodb.org/apt/ubuntu trusty/mongodb-org/3.2 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.2.list
##Suricata
add-apt-repository ppa:oisf/suricata-beta -y
##Holding pattern for dpkg...
print_status "${YELLOW}Waiting for dpkg process to free up...If this takes too long try running ${RED}sudo rm -f /var/lib/dpkg/lock${YELLOW} in another terminal window."
while fuser /var/lib/dpkg/lock >/dev/null 2>&1; do
   sleep 1
done

# System updates
print_status "${YELLOW}Performing apt-get update and upgrade (May take a while if this is a fresh install)..${NC}"
apt-get update &>> $logfile && apt-get -y upgrade &>> $logfile
error_check 'System updates'

print_status "${YELLOW}Installing:${NC} autoconf automake checkinstall clamav clamav-daemon clamav-daemon clamav-freshclam curl exiftool geoip-database libarchive-dev libboost-all-dev libcap2-bin libconfig-dev libfuzzy-dev libgeoip-dev libhtp1 libjpeg-dev libmagic1 libssl-dev libtool libvirt-dev mongodb-org=3.2.11 mono-utils openjdk-8-jre-headless p7zip-full python python-bottle python-bson python-chardet python-dev python-dpkt python-geoip python-jinja2 python-libvirt python-m2crypto python-magic python-pefile python-pip python-pymongo python-yara suricata ssdeep swig tcpdump unzip upx-ucl uthash-dev virtualbox wget wkhtmltopdf xfonts-100dpi xvfb yara .."

declare -a packages=(autoconf automake checkinstall clamav clamav-daemon clamav-daemon clamav-freshclam curl exiftool geoip-database libarchive-dev libboost-all-dev libcap2-bin libconfig-dev libfuzzy-dev libgeoip-dev libhtp1 libjpeg-dev libmagic1 libssl-dev libtool libvirt-dev mongodb-org=3.2.11 mono-utils openjdk-8-jre-headless p7zip-full python python-bottle python-bson python-chardet python-dev python-dpkt python-geoip python-jinja2 python-libvirt python-m2crypto python-magic python-pefile python-pip python-pymongo python-yara suricata ssdeep swig tcpdump unzip upx-ucl uthash-dev virtualbox wget wkhtmltopdf xfonts-100dpi xvfb yara);
install_packages ${packages[@]}
 

print_status "${YELLOW}Installing PIP requirments...Please Wait${NC}"
sudo -H pip install --upgrade pip
sudo -H pip uninstall clamd
sudo -H pip install -r $gitdir/requirements.txt

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
#wget http://sourceforge.net/projects/ssdeep/files/ssdeep-2.13/ssdeep-2.13.tar.gz/download -O ssdeep-2.13.tar.gz
#tar -zxf ssdeep-2.13.tar.gz
#cd ssdeep-2.13
#./configure
#make 
#make install
#pip install pydeep
sudo -H pip install git+https://github.com/kbandla/pydeep.git

##Malheur
cd $dir/tools/
git clone https://github.com/rieck/malheur.git
cd malheur
./bootstrap
./configure --prefix=/usr
make install

##Volatility
cd $dir/tools/ 
git clone https://github.com/volatilityfoundation/volatility.git
cd volatility
python setup.py build
python setup.py install

##Suricata
mkdir /etc/suricata/rules/cuckoo.rules
echo "alert http any any -> any any (msg:\"FILE store all\"; filestore; noalert; sid:15; rev:1;)"  | sudo tee /etc/suricata/rules/cuckoo.rules
cp $gitdir/suricata-cuckoo.yaml /etc/suricata/
cd $dir/tools/
git clone https://github.com/seanthegeek/etupdate
cd etupdate
mv etupdate /usr/sbin/
/usr/sbin/etupdate -V
chown $name:$name /usr/sbin/etupdate
chown -R $name:$name /etc/suricata/rules
crontab -u $name $gitdir/cron

##Other tools
cd $dir/tools/
apt-get install libboost-all-dev -y
sudo -H pip install git+https://github.com/buffer/pyv8 
git clone https://github.com/jpsenior/threataggregator.git
wget https://github.com/kevthehermit/VolUtility/archive/v1.0.tar.gz
tar -zxf v1.0*

##Cuckoo
cd /etc/
git clone https://github.com/spender-sandbox/cuckoo-modified.git
cd cuckoo-modified/
wget https://bitbucket.org/mstrobel/procyon/downloads/procyon-decompiler-0.5.30.jar
##Can probably remove one of the requirements.txt docs at some point
sudo -H pip install -r requirements.txt
sudo -H pip install django-ratelimit
cd utils/
python comm* --all --force
cd ..
cd data/yara/
git clone https://github.com/yara-rules/rules.git
cp rules/**/*.yar /etc/cuckoo-modified/data/yara/binaries/

##Remove Android and none working rules for now
mv /etc/cuckoo-modified/data/yara/binaries/Android* /etc/cuckoo-modified/data/yara/rules/
rm /etc/cuckoo-modified/data/yara/binaries/vmdetect.yar
rm /etc/cuckoo-modified/data/yara/binaries/antidebug_antivm.yar

##Copy over conf files
cd $gitdir/
cp *.conf /etc/cuckoo-modified/conf/
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

##Office Decrypt
cd /etc/cuckoo-modified/
mkdir work
git clone https://github.com/herumi/cybozulib
git clone https://github.com/herumi/msoffice
cd msoffice
make -j RELEASE=1

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
##DAMN THING NEVER INSTALLS!!!!!!
sudo -H pip install distorm3
##RANT OVER
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
read -p "Would you like to harden this host from malware Y/N" -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]
then
apt-get install unattended-upgrades apt-listchanges fail2ban -y
fi
echo
read -p "Would you like secure the Cuckoo webserver with SSL? Y/N" -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]
then
bash $gitdir/nginx.sh
fi
echo -e "${YELLOW}Installation complete, login as $name and open the terminal. In $name home folder you will find the start_cuckoo script. To get started as fast as possible you will need to create a virtualbox vm and name it ${RED}cuckoo1${NC}.${YELLOW} Take a snapshot after it has been created and is running the agent and python 27. Name the snapshot ${RED}vmcloak${YELLOW}. Alternatively you can create the VM with the vmcloak.sh script provided in your home directory. This will require you have a local copy of the Windows ISO you wish to use. You can then launch cuckoo_start.sh and navigate to $HOSTNAME:8000 or https://$HOSTNAME if Nginx was installed.${NC}"

