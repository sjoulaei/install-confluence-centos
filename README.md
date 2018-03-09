# Introduction
installer script to install Confluence in Centos 7 with postgresql database and reverse proxy ssl setup.
It installs:
* httpd24-httpd from scl repository
* postgresql server
* setup ssl certificates
* prepare confluence database

*This script is not meant to cover all basis. It is created to ease the installation of confluence on a fresh Centos7 installation.* 

I haven't spent much time on error handling and covering all various scenarios.
Tested on newly installed Centos7 machines on VM and DigitalOcean droplets.

Installation

#create new instance on Centos7 (minimal will do)
#yum install git
#cd /opt/
#git clone https://github.com/sjoulaei/install-confluence-centos.git
#cd install-confluence-centos
#./install-confluence.sh

Few questions will be asked about the details of the installation. The only one that you need to change is the password for the confluence database user. The rest can be left as default values (just press Enter).

Thats it!!! the script will take care of the rest of the installation.
