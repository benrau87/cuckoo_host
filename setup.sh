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
	print_good "$1 successfully."
else
	print_error "$1 failed. Please check $logfile for more details."
exit 1
fi

}

########################################
#Package installation function.

function install_packages()
{

apt-get update &>> $logfile && apt-get install -y --allow-unauthenticated ${@} &>> $logfile
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
dir_check /home/$name/tools
rm -rf /home/$name/tools/*
cd tools/

##Depos add
#this is a nice little hack I found in stack exchange to suppress messages during package installation.
export DEBIAN_FRONTEND=noninteractive

echo
print_status "${YELLOW}Adding Repositories...Please Wait${NC}"
#Mongodb
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 0C49F3730359A14518585931BC711F9BA15703C6 &>> $logfile
echo "deb [ arch=amd64,arm64 ] http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.4.list &>> $logfile
##Suricata
add-apt-repository ppa:oisf/suricata-beta -y &>> $logfile
##Holding pattern for dpkg...
print_status "${YELLOW}Waiting for dpkg process to free up...${NC}"
print_status "${YELLOW}If this takes too long try running ${RED}sudo rm -f /var/lib/dpkg/lock${YELLOW} in another terminal window.${NC}"
while fuser /var/lib/dpkg/lock >/dev/null 2>&1; do
   sleep 1
done

# System updates
print_status "${YELLOW}Performing apt-get update and upgrade (May take a while if this is a fresh install)..${NC}"
apt-get update &>> $logfile && apt-get -y upgrade &>> $logfile
error_check 'System updates'

print_status "${YELLOW}Installing:${NC} autoconf automake bison checkinstall clamav clamav-daemon clamav-daemon clamav-freshclam curl exiftool flex geoip-database libarchive-dev libboost-all-dev libcap2-bin libconfig-dev libfuzzy-dev libgeoip-dev libhtp1 libjpeg-dev libjansson-dev libmagic1 libmagic-dev libssl-dev libtool libvirt-dev mongodb-org=3.2.11 mono-utils openjdk-8-jre-headless p7zip-full python python-bottle python-bson python-chardet python-dev python-dpkt python-geoip python-jinja2 python-libvirt python-m2crypto python-magic python-pefile python-pip python-pymongo python-yara suricata ssdeep swig tcpdump unzip upx-ucl uthash-dev virtualbox wget wkhtmltopdf xfonts-100dpi xvfb yara .."

#mongodb-org=3.2.11
declare -a packages=(autoconf automake bison checkinstall clamav clamav-daemon clamav-daemon clamav-freshclam curl exiftool flex geoip-database libarchive-dev libboost-all-dev libcap2-bin libconfig-dev libfuzzy-dev libgeoip-dev libhtp1 libjpeg-dev libjansson-dev libmagic1 libmagic-dev libssl-dev libtool libvirt-dev mono-utils openjdk-8-jre-headless p7zip-full python python-bottle python-bson python-chardet python-dev python-dpkt python-geoip python-jinja2 python-libvirt python-m2crypto python-magic python-pefile python-pip python-pymongo python-yara suricata ssdeep swig tcpdump unzip upx-ucl uthash-dev virtualbox wget wkhtmltopdf xfonts-100dpi xvfb yara);
install_packages ${packages[@]}
 

print_status "${YELLOW}Upgrading PIP${NC}"
sudo -H pip install --upgrade pip &>> $logfile
error_check 'PIP upgrade'

print_status "${YELLOW}Installing PIP requirements${NC}"
sudo -H pip install -r $gitdir/requirements.txt &>> $logfile
error_check 'PIP requirements installation'

print_status "${YELLOW}Uninstalling Clamd if needed${NC}"
sudo -H pip uninstall clamd -y &>> $logfile
error_check 'Clamd uninistalled'

##Add user to vbox and enable mongodb
print_status "${YELLOW}Setting up Mongodb${NC}"
usermod -a -G vboxusers $name
systemctl start mongodb &>> $logfile
sleep 5
systemctl enable mongodb &>> $logfile
systemctl daemon-reload &>> $logfile
error_check 'Mongodb setup'

##tcpdump permissions
setcap cap_net_raw,cap_net_admin=eip /usr/sbin/tcpdump

##Yara
print_status "${YELLOW}Downloading Yara${NC}"
#wget https://github.com/VirusTotal/yara/archive/v3.5.0.tar.gz &>> $logfile
git clone https://github.com/VirusTotal/yara.git &>> $logfile
error_check 'Yara downloaded'
#tar -zxf v3.5.0.tar.gz &>> $logfile
print_status "${YELLOW}Installing Yara${NC}"
#cd yara-3.5.0
cd yara/
./bootstrap.sh &>> $logfile
./configure --with-crypto --enable-cuckoo --enable-magic &>> $logfile
error_check 'Yara compiled'
make &>> $logfile
make install &>> $logfile
make check &>> $logfile
error_check 'Yara installed'

##Pydeep
print_status "${YELLOW}Setting up Pydeep${NC}"
cd $dir/tools/
#wget http://sourceforge.net/projects/ssdeep/files/ssdeep-2.13/ssdeep-2.13.tar.gz/download -O ssdeep-2.13.tar.gz
#tar -zxf ssdeep-2.13.tar.gz
#cd ssdeep-2.13
#./configure
#make 
#make install
#pip install pydeep
sudo -H pip install git+https://github.com/kbandla/pydeep.git &>> $logfile
error_check 'Pydeep installeded'

##Malheur
print_status "${YELLOW}Setting up Malheur${NC}"
cd $dir/tools/
git clone https://github.com/rieck/malheur.git &>> $logfile
error_check 'Malheur downloaded'
cd malheur
./bootstrap &>> $logfile
./configure --prefix=/usr &>> $logfile
make install &>> $logfile
error_check 'Malheur installed'

##Volatility
print_status "${YELLOW}Setting up Volatility${NC}"
cd $dir/tools/ 
git clone https://github.com/volatilityfoundation/volatility.git &>> $logfile
error_check 'Volatility downloaded'
cd volatility
python setup.py build &>> $logfile
python setup.py install &>> $logfile
error_check 'Volatility installed'

##Suricata
print_status "${YELLOW}Setting up Suricata${NC}"
dir_check /etc/suricata/rules/cuckoo.rules
echo "alert http any any -> any any (msg:\"FILE store all\"; filestore; noalert; sid:15; rev:1;)"  | sudo tee /etc/suricata/rules/cuckoo.rules &>> $logfile
cp $gitdir/suricata-cuckoo.yaml /etc/suricata/
cd $dir/tools/
git clone https://github.com/seanthegeek/etupdate &>> $logfile
cd etupdate
mv etupdate /usr/sbin/
/usr/sbin/etupdate -V &>> $logfile
error_check 'Suricata updateded'
chown $name:$name /usr/sbin/etupdate &>> $logfile
chown -R $name:$name /etc/suricata/rules &>> $logfile
crontab -u $name $gitdir/cron &>> $logfile
error_check 'Suricata configured for auto-update'

##Other tools
print_status "${YELLOW}Grabbing other tools${NC}"
cd $dir/tools/
apt-get install libboost-all-dev -y &>> $logfile
sudo -H pip install git+https://github.com/buffer/pyv8 &>> $logfile
error_check 'PyV8 installed'
git clone https://github.com/jpsenior/threataggregator.git &>> $logfile
error_check 'Threat Aggregator downloaded'
wget https://github.com/kevthehermit/VolUtility/archive/v1.0.tar.gz &>> $logfile
error_check 'Volutility downloaded'
tar -zxf v1.0*

##Cuckoo
cd /etc/
rm -rf cuckoo-modified
print_status "${YELLOW}Downloading Cuckoo${NC}"
git clone https://github.com/spender-sandbox/cuckoo-modified.git  &>> $logfile
error_check 'Cuckoo downloaded'
cd cuckoo-modified/
print_status "${YELLOW}Downloading Java tools${NC}"
wget https://bitbucket.org/mstrobel/procyon/downloads/procyon-decompiler-0.5.30.jar  &>> $logfile
error_check 'Java tools downloaded'
##Can probably remove one of the requirements.txt docs at some point
print_status "${YELLOW}Installing any dependencies that may have been missed...Please wait${NC}"
sudo -H pip install -r requirements.txt &>> $logfile
sudo -H pip install django-ratelimit &>> $logfile
error_check 'Cuckoo dependencies'
cd utils/
python comm* --all --force &>> $logfile
error_check 'Community signature updated'
cd ..
cd data/yara/
print_status "${YELLOW}Downloading Yara Rules...Please wait${NC}"
git clone https://github.com/yara-rules/rules.git &>> $logfile
cp rules/**/*.yar /etc/cuckoo-modified/data/yara/binaries/ &>> $logfile
##Remove Android and none working rules for now
mv /etc/cuckoo-modified/data/yara/binaries/Android* /etc/cuckoo-modified/data/yara/rules/  &>> $logfile
rm /etc/cuckoo-modified/data/yara/binaries/vmdetect.yar  &>> $logfile
rm /etc/cuckoo-modified/data/yara/binaries/antidebug_antivm.yar  &>> $logfile
error_check 'Adding Yara rules'


##Copy over conf files
cd $gitdir/
cp *.conf /etc/cuckoo-modified/conf/
##Add vmcloak scripts 
chmod +x vmcloak.sh
cp vmcloak.sh $dir/
##Add windows python and PIL installers for VMs
cd $dir
dir_check windows_python_exe/
cp /etc/cuckoo-modified/agent/agent.py $dir/windows_python_exe/
cd windows_python_exe/
print_status "${YELLOW}Downloading Windows Python Depos${NC}"
wget http://effbot.org/downloads/PIL-1.1.7.win32-py2.7.exe &>> $logfile
wget https://www.python.org/ftp/python/2.7.11/python-2.7.11.msi &>> $logfile
error_check 'Windows depos downloaded'

##Office Decrypt
cd /etc/cuckoo-modified/
dir_check work
print_status "${YELLOW}Downloading Office Decrypt${NC}"
git clone https://github.com/herumi/cybozulib &>> $logfile
git clone https://github.com/herumi/msoffice &>> $logfile
cd msoffice
make -j RELEASE=1 &>> $logfile
error_check 'Office decrypt installed'

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

print_status "${YELLOW}Waiting for dpkg process to free up...${NC}"
print_status "${YELLOW}If this takes too long try running ${RED}sudo rm -f /var/lib/dpkg/lock${YELLOW} in another terminal window.${NC}"
while fuser /var/lib/dpkg/lock >/dev/null 2>&1; do
   sleep 1
done
##DAMN THING NEVER INSTALLS!!!!!!
sudo -H pip install distorm3 &>> $logfile
##RANT OVER
wait 1 &>> $logfile
echo
read -p "Do you want to iptable changes persistent? Y/N" -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]
then
echo
apt-get -qq install iptables-persistent -y &>> $logfile
fi
echo
read -p "Would you like to create VMs at this time? Y/N" -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]
then
echo
bash $dir/vmcloak.sh
fi
echo
read -p "Would you like to harden this host from malware Y/N" -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]
then
echo
apt-get install -qq unattended-upgrades apt-listchanges fail2ban -y  &>> $logfile
error_check 'Security upgrades'
fi
echo
read -p "Would you like secure the Cuckoo webserver with SSL? Y/N" -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]
then
echo
bash $gitdir/nginx.sh
fi
echo -e "${YELLOW}Installation complete, login as $name and open the terminal. In $name home folder you will find the start_cuckoo script. To get started as fast as possible you will need to create a virtualbox vm and name it ${RED}cuckoo1${NC}.${YELLOW} On the Windows VM install the windows_exes that can be found under the tools folder. Name the snapshot ${RED}vmcloak${YELLOW}. Alternatively you can create the VM with the vmcloak.sh script provided in your home directory. This will require you have a local copy of the Windows ISO you wish to use. You can then launch cuckoo_start.sh and navigate to $HOSTNAME:8000 or https://$HOSTNAME if Nginx was installed.${NC}"

exit 0
