#!/bin/bash

#icinga 2 setup


# update everything
yum update -y
yum install tmux mlocate wget curl gcc nano open-vm-tools net-tools -y
updatedb



icinga2_db_pass=icinga





function linebreak() {
    echo .
    echo .
    echo .
    echo ==========================================================================
    echo $1
    echo ==========================================================================
    echo .
    echo .
    echo .
}



function postgresql_install {

# get most up to date postgres 
yum install https://download.postgresql.org/pub/repos/yum/11/redhat/rhel-7-x86_64/pgdg-centos11-11-2.noarch.rpm -y

yum install postgresql11 -y
yum install postgresql11-server -y 

/usr/pgsql-11/bin/postgresql-11-setup initdb
systemctl enable postgresql-11 
systemctl start postgresql-11 

# install icinga data output
yum install icinga2-ido-pgsql -y 


cd /tmp
sudo -u postgres psql -c "CREATE ROLE icinga WITH LOGIN PASSWORD '$icinga2_db_pass';"
sudo -u postgres createdb -O icinga -E UTF8 icinga2
sudo -u postgres createdb -O icinga -E UTF8 icinga2web


# import dql schema 
export PFPASSWORD=
psql -U icinga -d icinga2 < /usr/share/icinga2-ido-pgsql/schema/pgsql.sql


systemctl restart postgresql-11.service


echo '
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# "local" is for Unix domain socket connections only
local   all             all                                     md5
# IPv4 local connections:
host    all             all             127.0.0.1/32            md5
# IPv6 local connections:
host    all             all             ::1/128                 md5
# Allow replication connections from localhost, by a user with the
# replication privilege.
local   replication     all                                     ident
host    replication     all             127.0.0.1/32            ident
host    replication     all             ::1/128                 ident

# icinga2
local   icinga2      icinga                            md5
host    icinga2      icinga      127.0.0.1/32          md5
host    icinga2      icinga      ::1/128               md5' > /var/lib/pgsql/11/data/pg_hba.conf

systemctl restart postgresql-11.service



# enable icinga2 ido for postgresql 
icinga2 feature enable ido-pgsql
systemctl restart icinga2

}

function install_php {

    yum install rh-php71-php-pgsql

    # enable php 7.1 
    systemctl start rh-php71-php-fpm.service
    systemctl enable rh-php71-php-fpm.service

    # install imagick support for pdf output
    yum install ImageMagick ImageMagick-devel -y
    yum install sclo-php71-php-pecl-imagick -y 

    systemctl restart rh-php71-php-fpm.service

    echo "extension=imagick.so" >> /etc/opt/rh/rh-php71/php.ini 
    echo 'date.timezone="America/Chicago"'  >> /etc/opt/rh/rh-php71/php.ini 


}

function install_httpd {
    yum install httpd -y 

    systemctl enable httpd
    systemctl start httpd

    cd /tmp
    openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes

}

function config_firewall {
    firewall-cmd --add-service=http
    firewall-cmd --add-service=https
    firewall-cmd --add-port=5665/tcp
    firewall-cmd --zone=public --permanent --add-service=http
    firewall-cmd --zone=public --permanent --add-service=https
    sudo firewall-cmd --zone=public --permanent --add-port=5665/tcp
    setsebool -P httpd_can_network_connect on
}





# ad required repositories
yum install https://packages.icinga.com/epel/icinga-rpm-release-7-latest.noarch.rpm -y 
yum install centos-release-scl -y
yum install epel-release -y


linebreak 'repos installed'



# install icinga2
yum install icinga2 -y 
systemctl enable icinga2
systemctl start icinga2


linebreak 'icinga2 installed'


# install the nagios plugins for monitoring
yum install nagios-plugins-all -y

linebreak 'nagios pluggins installed'

systemctl status icinga2
systemctl restart icinga2

# install selinux addon for icinga2
yum install icinga2-selinux -y 
yum install icingaweb2-selinux -y

linebreak 'icinga2-selinux installed'


# enable nano syntax highlighting 
yum install nano-icinga2 -y
cp /etc/nanorc ~/.nanorc

postgresql_install
linebreak 'postgresql installed'

# isntall the web components
yum install icingaweb2 icingacli -y

linebreak 'icingaweb icingacli installed'

install_php

linebreak 'php configured'


install_httpd

linebreak 'httpd installed'

config_firewall

linebreak 'firewall configured'






systemctl restart postgresql-11
systemctl restart rh-php71-php-fpm.service
systemctl restart icinga2



icingacli setup token create 