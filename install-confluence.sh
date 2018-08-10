#!/bin/bash
#Colours
#RED="\033[31m"
#GREEN="\033[32m"
#BLUE="\033[34m"
#RESET="\033[0m"

#####################################################################
# Custom answers	                                            #
#####################################################################
#update the answers below as per your requirements
# database name, user and password that Confluence will use
confluence_user=confluence_user
confluence_usr_pwd=ch@ngeTH!s
confluence_db=confluence_db

#copy your ssl certificates
#For SSL certificates to work properly you need to copy the certificate files into the right location. 
#I assume you have created them and have them in below addresses:"
#Default location: certificate file: /etc/pki/tls/certs/your_cert_file.crt"
#Default location: certificate key file: /etc/pki/tls/private/your_private_key_file.key"
ssl_crt="localhost.crt"
ssl_key="localhost.key"
#to access from outside change this to public address. e.g. confluence.yourdomain.com
server_add="localhost"
http_port="8090"
control_port="8000"
#Confluence server version that you want to install.
confluence_ver="6.10.1"
#Java keystore password default value. Default value most certainly hasn't been changed.
keystore_pwd=changeit

###################################################################
#Start Environment Preparation
###################################################################
#general prep
echo -e "\033[32m Install some generic packages\033[0m"
yum update -y
yum install -y  vim wget centos-release-scl\
		https://download.postgresql.org/pub/repos/yum/9.6/redhat/rhel-7-x86_64/pgdg-centos96-9.6-3.noarch.rpm

#install required packages
echo -e "\033[32mInstall packages you need for confluence\033[0m"
yum install -y  postgresql96-server\
                httpd24-httpd httpd24-mod_ssl httpd24-mod_proxy_html

#Selinux config mode update to permissive

echo -e "\033[32mFor apache to work properly with ssl, change the mode to permissive\033[0m"
sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config && echo SUCCESS || echo FAILURE


#setup database server
/usr/pgsql-9.6/bin/postgresql96-setup initdb



#set postgresql to accept connections
sed -i "s|host    all             all             127.0.0.1/32.*|host    all             all             127.0.0.1/32            md5|" /var/lib/pgsql/9.6/data/pg_hba.conf  && echo "pg_hba.conf file updated successfully" || echo "failed to update pg_hba.conf"

systemctl enable postgresql-9.6
systemctl start postgresql-9.6

#prepare database: 
#create database, user and grant permissions to the user
printf "CREATE USER $confluence_user WITH PASSWORD '$confluence_usr_pwd';\nCREATE DATABASE $confluence_db WITH ENCODING='UNICODE' LC_COLLATE='C' LC_CTYPE='C' TEMPLATE=template0;\nGRANT ALL PRIVILEGES ON DATABASE $confluence_db TO $confluence_user;" > myconf/confluence-db.sql

sudo -u postgres psql -f myconf/confluence-db.sql


#create customised files
cp -v CONF/httpd/confluence.conf myconf/
cp -v CONF/confluence/server.xml myconf/
cp -v CONF/confluence/response.varfile myconf/


#############################################################################
#Setup Apache Server
#############################################################################
#update confluence.conf virtual host file

mkdir -pv /opt/rh/httpd24/root/var/www/confluence/logs/

sed -i "s|SSLCertificateFile.*|SSLCertificateFile /etc/pki/tls/certs/$ssl_crt|" myconf/confluence.conf  && echo "cert info added to confluence.conf file successfully" || echo "cert info update on confluence.conf file failed"
sed -i "s|SSLCertificateKeyFile.*|SSLCertificateKeyFile /etc/pki/tls/private/$ssl_key|" myconf/confluence.conf && echo "ssl key info added to confluence.conf file successfully" || echo "ssl key info update on confluence.conf file failed"
sed -i "s|confluence.yoursite.com|$server_add|g" myconf/confluence.conf  && echo "server address updated on confluence.conf file successfully" || echo "server address update on confluence.conf failed"
sed -i "s|8090|$http_port|g" myconf/confluence.conf  && echo "server port updated on confluence.conf file successfully" || echo "server port update on confluence.conf failed"

sed -i "s|confluence.yoursite.com|$server_add|g" myconf/server.xml  && echo "server address updated on server.xml file successfully" || echo "server address update on server.xml failed"

#setup apache server
systemctl enable httpd24-httpd
systemctl start httpd24-httpd 
cp -v myconf/confluence.conf /opt/rh/httpd24/root/etc/httpd/conf.d/


#############################################################################
#download and prepare confluence
#############################################################################

sed -i "s|8090|$http_port|g" myconf/response.varfile  && echo "http port updated on successfully" || echo "server port update on confluence.conf failed"
sed -i "s|8000|$control_port|g" myconf/response.varfile  && echo "control port updated on successfully" || echo "server port update on confluence.conf failed"


wget -P download/  https://product-downloads.atlassian.com/software/confluence/downloads/atlassian-confluence-$confluence_ver-x64.bin
chmod u+x download/atlassian-confluence-$confluence_ver-x64.bin
sh download/atlassian-confluence-$confluence_ver-x64.bin -q -varfile ../myconf/response.varfile

#copy updated server.xml file
cp -v myconf/server.xml /opt/atlassian/confluence/conf/server.xml

#add ssl certificate to java key store
echo -e "\033[32mSSL certification is going to be added to confluence java keystore\033[0m"
/opt/atlassian/confluence/jre/bin/keytool -import -alias $server_add -keystore /opt/atlassian/confluence/jre/lib/security/cacerts -storepass $keystore_pwd -file /etc/pki/tls/certs/$ssl_crt -noprompt

###############################################################################
#finally reboot the server
###############################################################################
echo -e "\033[32mGreat!!! confluence installation completed successfully."
echo "Your system needs to be rebooted before you can continue to setup your system from GUI."
echo "After restart you need to complete the setup from a web browser. Navigate to: https://$server_add"
echo -e "\033[31m=======Press Any Key to reboot the system!!!!!!!========\033[0m"
read -n1
echo
reboot

