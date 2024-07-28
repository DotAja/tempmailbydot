#!/bin/bash

# Update system
apt update && apt upgrade -y

# Install Postfix dan Dovecot
apt install -y postfix dovecot-core dovecot-imapd apache2 php libapache2-mod-php

# Konfigurasi Postfix
tee /etc/postfix/main.cf > /dev/null <<EOF
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

tee /etc/postfix/virtual > /dev/null <<EOF
@mail-dot.x10.mx emailuser
EOF

postmap /etc/postfix/virtual

# Konfigurasi Dovecot
tee /etc/dovecot/dovecot.conf > /dev/null <<EOF
protocols = imap
EOF

tee /etc/dovecot/conf.d/10-mail.conf > /dev/null <<EOF
mail_location = maildir:~/Maildir
EOF

tee /etc/dovecot/conf.d/10-auth.conf > /dev/null <<EOF
disable_plaintext_auth = no
EOF

tee /etc/dovecot/conf.d/10-master.conf > /dev/null <<EOF
service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0660
    user = postfix
    group = postfix
  }
}
EOF

# Tambah pengguna mail baru
useradd -m emailuser -s /bin/false
echo "emailuser:password" | chpasswd

# Mulai ulang layanan
systemctl restart postfix
systemctl restart dovecot

# Instal dependensi untuk antarmuka web
apt install -y git curl

# Buat direktori antarmuka web
mkdir -p /var/www/html/tempemail

# Buat skrip PHP untuk antarmuka web
tee /var/www/html/tempemail/index.php > /dev/null <<EOF
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

tee /var/www/html/tempemail/messages.php > /dev/null <<EOF
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

# Setel izin
chown -R www-data:www-data /var/www/html/tempemail

# Mulai ulang Apache
systemctl restart apache2

echo "Setup selesai. Akses layanan email sementara Anda di http://your-server-ip/tempemail"
