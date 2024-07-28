#!/bin/bash

# Update sistem
apt update
apt upgrade -y

# Install dependensi
apt install apache2 php php-mysql php-mbstring php-xml mariadb-server postfix dovecot-core dovecot-imapd unzip -y

# Install PostfixAdmin
wget https://sourceforge.net/projects/postfixadmin/files/latest/download -O postfixadmin-latest.tar.gz
tar -xzf postfixadmin-latest.tar.gz
mv postfixadmin-*/ /var/www/html/postfixadmin
chown -R www-data:www-data /var/www/html/postfixadmin

# Install RainLoop
wget https://www.rainloop.net/repository/webmail/rainloop-latest.zip
unzip rainloop-latest.zip -d /var/www/html/rainloop
chown -R www-data:www-data /var/www/html/rainloop

# Konfigurasi Apache
tee -a /etc/apache2/sites-available/000-default.conf > /dev/null <<EOL
Alias /postfixadmin /var/www/html/postfixadmin
<Directory /var/www/html/postfixadmin>
    Options Indexes FollowSymLinks MultiViews
    AllowOverride All
    Require all granted
</Directory>

Alias /rainloop /var/www/html/rainloop
<Directory /var/www/html/rainloop>
    Options Indexes FollowSymLinks MultiViews
    AllowOverride All
    Require all granted
</Directory>
EOL

a2enmod rewrite
systemctl restart apache2

# Konfigurasi Postfix
tee -a /etc/postfix/main.cf > /dev/null <<EOL
myhostname = mail-dot.x10.mx
mydomain = mail-dot.x10.mx
myorigin = \$mydomain
inet_interfaces = all
mydestination = \$myhostname, localhost.\$mydomain, localhost
virtual_mailbox_domains = mysql:/etc/postfix/mysql-virtual-mailbox-domains.cf
virtual_mailbox_maps = mysql:/etc/postfix/mysql-virtual-mailbox-maps.cf
virtual_alias_maps = mysql:/etc/postfix/mysql-virtual-alias-maps.cf
EOL

# Buat file konfigurasi MySQL untuk Postfix
tee /etc/postfix/mysql-virtual-mailbox-domains.cf > /dev/null <<EOL
user = postfixadmin
password = your_password
hosts = 127.0.0.1
dbname = postfixadmin
query = SELECT domain FROM domain WHERE domain='%s'
EOL

tee /etc/postfix/mysql-virtual-mailbox-maps.cf > /dev/null <<EOL
user = postfixadmin
password = your_password
hosts = 127.0.0.1
dbname = postfixadmin
query = SELECT maildir FROM mailbox WHERE username='%s'
EOL

tee /etc/postfix/mysql-virtual-alias-maps.cf > /dev/null <<EOL
user = postfixadmin
password = your_password
hosts = 127.0.0.1
dbname = postfixadmin
query = SELECT goto FROM alias WHERE address='%s'
EOL

# Konfigurasi Dovecot
tee -a /etc/dovecot/dovecot.conf > /dev/null <<EOL
mail_location = maildir:/var/mail/vhosts/%d/%n
EOL

tee -a /etc/dovecot/conf.d/10-mail.conf > /dev/null <<EOL
mail_location = maildir:/var/mail/vhosts/%d/%n
EOL

# Restart layanan
systemctl restart postfix
systemctl restart dovecot
