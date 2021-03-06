#!/bin/bash
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo
echo -e "${YELLOW}Please enter the name of the cuckoo user account${NC}"
read user
echo

echo
echo -e "${YELLOW}What is the Hostname or IP address of the machine that is hosting the cuckoo webpage?${NC}"
read ipaddr
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
mv /etc/nginx/cuckoo /etc/nginx/ssl
chown -R root:www-data /etc/nginx/ssl
chmod -R u=rX,g=rX,o= /etc/nginx/ssl

##Remove default sites and create new cuckoo site
rm /etc/nginx/sites-enabled/default

sudo tee -a /tmp/cuckoo <<EOF
server {
    listen $ipaddr:443 ssl http2;
    ssl_certificate /etc/nginx/ssl/cuckoo.crt;
    ssl_certificate_key /etc/nginx/ssl/cuckoo.key;
    ssl_dhparam /etc/nginx/ssl/dhparam.pem;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_prefer_server_ciphers on;
    ssl_ciphers "EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH";
    ssl_ecdh_curve secp384r1; # Requires nginx >= 1.1.0
    ssl_session_cache shared:SSL:10m;
    ssl_session_tickets off; # Requires nginx >= 1.5.9
    # Uncomment this next line if you are using a signed, trusted cert
    #add_header Strict-Transport-Security "max-age=63072000; includeSubdomains; preload";
    add_header X-Frame-Options SAMEORIGIN;
    add_header X-Content-Type-Options nosniff;
    root /usr/share/nginx/html;
    index index.html index.htm;
    client_max_body_size 101M;
    auth_basic "Login required";
    auth_basic_user_file /etc/nginx/htpasswd;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    location /storage/analysis {
       alias /etc/cuckoo-modified/storage/analyses/;
       autoindex on;
       autoindex_exact_size off;
       autoindex_localtime on;
    }

    location /static {
      alias /etc/cuckoo-modified/web/static/;
    }
}

server {
    listen $ipaddr:80 http2;
    return 301 https://\$server_name$request_uri;
}


#server {
#  listen 192.168.100.1:8080;

#   root /home/cuckoo/vmshared;

#     location / {
#           try_files \$uri \$uri/ =404;
#           autoindex on;
#           autoindex_exact_size off;
#           autoindex_localtime on;
#     }
#}
# Host the upstream legacy API 
server {
    listen $ipaddr:4343 ssl http2;
    ssl_certificate /etc/nginx/ssl/cuckoo.crt;
    ssl_certificate_key /etc/nginx/ssl/cuckoo.key;
    ssl_dhparam /etc/nginx/ssl/dhparam.pem;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_prefer_server_ciphers on;
    ssl_ciphers "EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH";
    ssl_ecdh_curve secp384r1; # Requires nginx >= 1.1.0
    ssl_session_cache shared:SSL:10m;
    ssl_session_tickets off; # Requires nginx >= 1.5.9
   # Uncomment this next line if you are using a signed, trusted cert
    #add_header Strict-Transport-Security "max-age=63072000; includeSubdomains; preload";
    add_header X-Frame-Options SAMEORIGIN;
    add_header X-Content-Type-Options nosniff;
    root /usr/share/nginx/html;
    index index.html index.htm;
    client_max_body_size 101M;

    location / {
        proxy_pass http://127.0.0.1:8001;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        
        # Restrict access
       #allow IP_Address;
      #allow 192.168.1.0/24;
      #deny all;
    }
}
EOF

mv /tmp/cuckoo /etc/nginx/sites-available/
ln -s /etc/nginx/sites-available/cuckoo /etc/nginx/sites-enabled/cuckoo

##Create web user and secure password storage
echo -e "${YELLOW}Please type in a user name for the website.${NC}"
read webuser
htpasswd -c /etc/nginx/htpasswd $webuser
chown root:www-data /etc/nginx/htpasswd
chmod u=rw,g=r,o= /etc/nginx/htpasswd

##Create and restart service
systemctl enable nginx.service
service nginx restart






