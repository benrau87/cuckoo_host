#!/bin/bash
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Please enter the name of the cuckoo user account${NC}"
read user
echo

##Install nginx
apt-get -qq install nginx apache2-utils -y
usermod -a -G cuckoo $user

##Create and secure keys
mkdir /etc/ssl/cuckoo/
cd /etc/ssl/cuckoo/
openssl req -x509 -nodes -days 365 -newkey rsa:4096 -keyout cuckoo.key -out cuckoo.crt
openssl dhparam -out dhparam.pem 4096
cd ..
mv cuckoo /etc/nginx
chown -R root:www-data /etc/nginx/ssl
chmod -R u=rX,g=rX,o= /etc/nginx/ssl

##Remove default sites
rm /etc/nginx/sites-enabled/default



