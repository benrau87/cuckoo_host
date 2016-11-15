#!/bin/bash
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi
dir=$PWD
echo "What would you like your Cuckoo username to be?"
read name
adduser $name

##Depos add
echo "Installing Dependencies...Please Wait"
apt-get -qq update -y
apt-get -qq dist-upgrade -y
apt-get -qq install git mongodb python-requests libffi-dev build-essential python-django python python-dev python-pip python-pil python-sqlalchemy python-bson python-dpkt python-jinja2 python-magic python-pymongo python-gridfs python-libvirt python-bottle python-pefile python-chardet tcpdump -y

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
wget https://github.com/cuckoosandbox/cuckoo/archive/2.0-rc1.zip
unzip 2.0-rc*
chown -R $name:$name cuckoo*/
pip install -r cuckoo*/requirements.txt
mkdir windows_python_exe/
cd windows_python_exe/
wget http://effbot.org/downloads/PIL-1.1.7.win32-py2.7.exe
wget https://www.python.org/ftp/python/2.7.11/python-2.7.11.amd64.msi
cd ..
touch start_server.sh
chmod +x start_server.sh
echo " #!/bin/bash
       python -m SimpleHTTPServer 8181" > start_server.sh

echo
echo "Installation complete, login as $name and open the terminal. In the cuckoo folder under ~, you can launch start_sever.sh to share agent and exe's. Report webpage is at http://localhost:8000"

echo "pref("browser.startup.homepage", "http://localhost:8000"" | tee -a /etc/firefox/syspref.js
