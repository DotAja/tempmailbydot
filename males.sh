#!/bin/bash

# Update sistem
sudo apt update
sudo apt upgrade -y

# Install dependensi
sudo apt install apache2 php php-mysql php-mbstring php-xml mariadb-server postfix dovecot-core dovecot-imapd -y

# Install PostfixAdmin
wget https://sourceforge.net/projects/postfixadmin/files/postfixadmin/postfixadmin-3.3.10/postfixadmin-3.3.10.tar.gz
tar -xzf postfixadmin-3.3.10.tar.gz
sudo mv postfixadmin-3.3.10 /var/www/html/postfixadmin
sudo chown -R www-data:www-data /var/www/html/postfixadmin

# Install RainLoop
wget http://www.rainloop.net/repository/webmail/rainloop-latest.zip
unzip rainloop-latest.zip -d /var/www/html/rainloop
sudo chown -R www-data:www-data /var/www/html/rainloop

# Konfigurasi Apache
sudo tee -a /etc/apache2/sites-available/000-default.conf > /dev/null <<EOL
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

sudo a2enmod rewrite
sudo systemctl restart apache2

# Konfigurasi Postfix
sudo tee -a /etc/postfix/main.cf > /dev/null <<EOL
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
sudo tee /etc/postfix/mysql-virtual-mailbox-domains.cf > /dev/null <<EOL
user = dotaja
password = dotaja123
hosts = 127.0.0.1
dbname = postfixadmin
query = SELECT domain FROM domain WHERE domain='%s'
EOL

sudo tee /etc/postfix/mysql-virtual-mailbox-maps.cf > /dev/null <<EOL
user = dotaja
password = dotaja123
hosts = 127.0.0.1
dbname = postfixadmin
query = SELECT maildir FROM mailbox WHERE username='%s'
EOL

sudo tee /etc/postfix/mysql-virtual-alias-maps.cf > /dev/null <<EOL
user = dotaja
password = dotaja123
hosts = 127.0.0.1
dbname = postfixadmin
query = SELECT goto FROM alias WHERE address='%s'
EOL

# Konfigurasi Dovecot
sudo tee -a /etc/dovecot/dovecot.conf > /dev/null <<EOL
mail_location = maildir:/var/mail/vhosts/%d/%n
EOL

sudo tee -a /etc/dovecot/conf.d/10-mail.conf > /dev/null <<EOL
mail_location = maildir:/var/mail/vhosts/%d/%n
EOL

# Restart layanan
sudo systemctl restart postfix
sudo systemctl restart dovecot
