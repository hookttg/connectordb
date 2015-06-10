#!/bin/bash

INSTALLDIR=$(pwd)

#This script is run on a just-initialized server. It needs root access.

#First, update the shit out of everything
apt-get -y update
apt-get -y upgrade
apt-get -y autoremove  #Sometimes kernels are not removed automatically

#Next, get all the necessary libraries
apt-get -y install cryptsetup python-dev build-essential htop wget tmux
apt-get -y install postgresql redis-server git nginx 
apt-get -y install python-nose python-apsw python-coverage python-pip
pip install subprocess32

#We don't want the servers to start on boot (except for nginx)
systemctl disable postrgresql.service
systemctl stop postgresql.service

#Replace {{CONNECTORDB_DIR}} with the install directory
find . -type f -print0 | xargs -0 sed -i "s@{{CONNECTORDB_DIR}}@${INSTALLDIR}@g"

#Set up ssl dhparams (logjam testers want at least 2048 key)
openssl dhparam -out ssl/dhparams.pem 2048
chmod -R 000 ssl

#Alright, now set up nginx
if [ -f "/etc/nginx/sites-enabled/default" ];
then
    rm /etc/nginx/sites-enabled/default
fi
mv ./nginx_config /etc/nginx/sites-available/connectordb
ln -s /etc/nginx/sites-available/connectordb /etc/nginx/sites-enabled/connectordb

sudo systemctl restart nginx.service

#Copy dot files
for f in DOT_*; do mv $f ".${f#DOT_}"; done
chmod +x .tmx

#Set up iptables rules
sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
sudo iptables -A INPUT -j DROP
sudo apt-get -y install iptables-persistent #Just say yes to everything that it asks when installing

#fail2ban should come automatically with sshd enabled. We should look at implementing a fail2ban module for connectordb
sudo apt-get -y install fail2ban    #Ain't nobody password-spamming our servers
sudo systemctl enable fail2ban.service
sudo systemctl start fail2ban.service 

#And now, install a recent version of golang
mkdir tmp
cd tmp
wget https://storage.googleapis.com/golang/go1.4.2.linux-amd64.tar.gz
tar -C /usr/local -xzf go1.4.2.linux-amd64.tar.gz
cd ..
rm -rf tmp


#Now clone the database - needs auth
git clone https://github.com/dkumor/connectordb.git

#And finally, set up the python module. This installs the deps for python module
cd connectordb/src/clients/python
python setup.py install
cd ~

chmod +x cryptify

#aaaand we're done
echo "Finished"