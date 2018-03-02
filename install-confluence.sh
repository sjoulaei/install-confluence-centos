#!/bin/bash

#Colours
#RED="\033[31m"
#GREEN="\033[32m"
#BLUE="\033[34m"
#RESET="\033[0m"

#general prep
echo -e "\033[32m Install some generic packages\033[0m"
yum update -y
yum install -y  vim wget centos-release-scl

#install required packages
echo -e "\033[32mInstall packages you need for confluence\033[0m"
yum install -y  postgresql-server\
                httpd24-httpd httpd24-mod_ssl httpd24-mod_proxy_html

#setup database server
postgresql-setup initdb
export PGDATA=/var/lib/pgsql/data
systemctl enable postgresql

#set postgresql to accept connections
sed -i "s|host    all             all             127.0.0.1/32.*|host    all             all             127.0.0.1/32            md5|" /var/lib/pgsql/data/pg_hba.conf  && echo "pg_hba.conf file updated successfully" || echo "failed to update pg_hba.conf"

systemctl start postgresql

#prepare database: create database, user and grant permissions to the user
echo "now it's time to prepare the database. Keep record of your answers to next questions as you will need them later when starting your server on GUI"
read -p "Enter the confluence user name you want to create(confluence_user): " confluence_user
confluence_user=${confluence_user:-confluence_user}
read -sp "Enter the new confluence user password: " confluence_usr_pwd
echo
read -p "Enter the confluence database you want to create (confluence_db): " confluence_db
confluence_db=${confluence_db:-confluence_db}

printf "CREATE USER $confluence_user WITH PASSWORD '$confluence_usr_pwd';\nCREATE DATABASE $confluence_db WITH ENCODING='UTF8' OWNER=$confluence_user CONNECTION LIMIT=-1;" > confluence-db.sql

sudo -u postgres psql -f confluence-db.sql
sudo -u postgres psql -d "$confluence_db" -c "GRANT ALL ON ALL TABLES IN SCHEMA public TO $confluence_user;"
sudo -u postgres psql -d "$confluence_db" -c "GRANT ALL ON SCHEMA public TO $confluence_user;"


#Selinux config mode update to permissive

echo -e "\033[32mFor apache to work properly with ssl, change the mode to permissive"
echo -e "Press any key to update the config file or Ctrl-c to exit.\033[0m"
read -n1
echo
sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config && echo SUCCESS || echo FAILURE


#copy your ssl certificates
echo -e "For SSL certificates to work properly you need to copy the certificate files into the right location. I assume you have them in below addresses:"
echo -e "  - certificate file: /etc/pki/tls/certs/your_cert_file.crt"
echo -e "  - certificate key file: /etc/pki/tls/private/your_private_key_file.key"

read -p "Enter the ssl certification file name (localhost.crt):" ssl_crt
ssl_crt=${ssl_crt:-"localhost.crt"}
read -p "Enter the ssl certification private key file name (localhost.key):" ssl_key
ssl_key=${ssl_key:-"localhost.key"}


#update confluence.conf virtual host file
read -p "Enter your server address (youraddress.com):" server_add
server_add=${server_add:-"youraddress.com"}

read -p "Enter your confluence server port (8090):" server_port
server_port=${server_port:-"8090"}

cp -v CONF/httpd/confluence.conf /opt/rh/httpd24/root/etc/httpd/conf.d/
mkdir -pv /opt/rh/httpd24/root/var/www/confluence/logs/

sed -i "s|SSLCertificateFile.*|SSLCertificateFile /etc/pki/tls/certs/$ssl_crt|" /opt/rh/httpd24/root/etc/httpd/conf.d/confluence.conf  && echo "cert info added to confluence.conf file successfully" || echo "cert info update on confluence.conf file failed"
sed -i "s|SSLCertificateKeyFile.*|SSLCertificateKeyFile /etc/pki/tls/private/$ssl_key|" /opt/rh/httpd24/root/etc/httpd/conf.d/confluence.conf  && echo "ssl key info added to confluence.conf file successfully" || echo "ssl key info update on confluence.conf file failed"
sed -i "s|ServerName.*|ServerName $server_add|" /opt/rh/httpd24/root/etc/httpd/conf.d/confluence.conf  && echo "ServerName added to confluence.conf file successfully" || echo "ServerName update on confluence.conf file failed"
sed -i "s|ServerAlias.*|ServerAlias $server_add|" /opt/rh/httpd24/root/etc/httpd/conf.d/confluence.conf  && echo "ServerAlias added to confluence.conf file successfully" || echo "ServerAlias update on confluence.conf file failed"
sed -i "s|ProxyPass.*|ProxyPass / http://$server_add:$server_port/|" /opt/rh/httpd24/root/etc/httpd/conf.d/confluence.conf  && echo "ProxyPass added to confluence.conf file successfully" || echo "ProxyPass update on confluence.conf file failed"
sed -i "s|ProxyPassReverse.*|ProxyPassReverse / http://$server_add:$server_port/|" /opt/rh/httpd24/root/etc/httpd/conf.d/confluence.conf  && echo "ProxyPassReverse added to confluence.conf file successfully" || echo "ProxyPassReverse update on confluence.conf file failed"
sed -i "s|Redirect Permanent.*|Redirect Permanent / https://$server_add/|" /opt/rh/httpd24/root/etc/httpd/conf.d/confluence.conf  && echo "Redirect added to confluence.conf file successfully" || echo "Redirect update on confluence.conf file failed"


#setup apache server
systemctl enable httpd24-httpd
systemctl start httpd24-httpd 

#download and prepare confluence
echo -e "\033[32mDownload and prepare latest version of confluence package\033[0m"
read -p "Enter the version of confluence you want to install(6.7.10):" confluence_ver
confluence_ver=${confluence_ver:-"6.7.1"}

wget https://product-downloads.atlassian.com/software/confluence/downloads/atlassian-confluence-$confluence_ver-x64.bin
chmod +x atlassian-confluence-$confluence_ver-x64.bin
sh atlassian-confluence-$confluence_ver-x64.bin

#add ssl certificate to java key store
echo -e "\033[32mSSL certification is going to be added to confluence java keystore\033[0m"
read -p "What is the password for keystore(changeit):" keystore_pwd
keystore_pwd=${keystore_pwd:-"changeit"}
/opt/atlassian/confluence/jre/bin/keytool -import -alias $server_add -keystore /opt/atlassian/confluence/jre/lib/security/cacerts -storepass $keystore_pwd -file /etc/pki/tls/certs/$ssl_crt


#reboot
echo -e "\033[32mGreat!!! confluence installation completed successfully."
echo "Your system needs to be rebooted before you can continue to setup your system from GUI."
echo "After restart you need to complete the setup from a web browser. Navigate to: https://$server_add"
echo -e "\033[31m=======Press Any Key to reboot the system!!!!!!!========\033[0m"
read -n1
echo
reboot
