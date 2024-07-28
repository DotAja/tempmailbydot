#!/bin/bash

# Update system
sudo apt update && sudo apt upgrade -y

# Install Postfix and Dovecot
sudo apt install -y postfix dovecot-core dovecot-imapd apache2 php libapache2-mod-php

# Configure Postfix
sudo tee /etc/postfix/main.cf > /dev/null <<EOF
myhostname = mail-dot.x10.mx
mydomain = x10.mx
myorigin = /etc/mailname
mydestination = \$myhostname, localhost.\$mydomain, localhost, \$mydomain
relayhost =
mynetworks = 127.0.0.0/8
mailbox_size_limit = 0
recipient_delimiter = +
inet_interfaces = all
inet_protocols = all
virtual_alias_maps = hash:/etc/postfix/virtual
EOF

sudo tee /etc/postfix/virtual > /dev/null <<EOF
@mail-dot.x10.mx emailuser
EOF

sudo postmap /etc/postfix/virtual

# Configure Dovecot
sudo tee /etc/dovecot/dovecot.conf > /dev/null <<EOF
protocols = imap
EOF

sudo tee /etc/dovecot/conf.d/10-mail.conf > /dev/null <<EOF
mail_location = maildir:~/Maildir
EOF

sudo tee /etc/dovecot/conf.d/10-auth.conf > /dev/null <<EOF
disable_plaintext_auth = no
EOF

sudo tee /etc/dovecot/conf.d/10-master.conf > /dev/null <<EOF
service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0660
    user = postfix
    group = postfix
  }
}
EOF

# Add mail user
sudo useradd -m emailuser -s /bin/false
echo "emailuser:password" | sudo chpasswd

# Restart services
sudo systemctl restart postfix
sudo systemctl restart dovecot

# Install dependencies for web interface
sudo apt install -y git curl

# Create web interface directory
sudo mkdir -p /var/www/html/tempemail

# Create web interface PHP script
sudo tee /var/www/html/tempemail/index.php > /dev/null <<EOF
<?php
function generateRandomEmail(\$domain) {
    \$characters = 'abcdefghijklmnopqrstuvwxyz0123456789';
    \$randomString = '';
    for (\$i = 0; \$i < 10; \$i++) {
        \$randomString .= \$characters[rand(0, strlen(\$characters) - 1)];
    }
    return \$randomString . '@' . \$domain;
}

if (isset(\$_POST['generate'])) {
    \$temporaryEmail = generateRandomEmail('mail-dot.x10.mx');
    echo "Email sementara Anda: <strong>" . \$temporaryEmail . "</strong><br>";
    echo "Pesan:<br><iframe src='messages.php?email=' . \$temporaryEmail' width='100%' height='400px'></iframe>";
} else {
    echo "<form method='POST'><input type='submit' name='generate' value='Generate Mail'></form>";
}
?>
EOF

sudo tee /var/www/html/tempemail/messages.php > /dev/null <<EOF
<?php
if (isset(\$_GET['email'])) {
    \$email = \$_GET['email'];
    \$dir = "/home/emailuser/Maildir/";
    \$folders = ['new', 'cur'];
    
    foreach (\$folders as \$folder) {
        \$path = \$dir . \$folder;
        if (is_dir(\$path)) {
            \$files = scandir(\$path);
            foreach (\$files as \$file) {
                if (\$file != '.' && \$file != '..') {
                    \$message = file_get_contents(\$path . '/' . \$file);
                    if (strpos(\$message, \$email) !== false) {
                        echo nl2br(htmlspecialchars(\$message)) . "<hr>";
                    }
                }
            }
        }
    }
}
?>
EOF

# Set permissions
sudo chown -R www-data:www-data /var/www/html/tempemail

# Restart Apache
sudo systemctl restart apache2

echo "Setup completed. Access your temporary email service at http://your-server-ip/tempemail"
