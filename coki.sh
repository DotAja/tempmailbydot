#!/bin/bash

# Update sistem
sudo apt update
sudo apt upgrade -y

# Install Postfix
sudo debconf-set-selections <<< "postfix postfix/mailname string namaku-dot.x10.mx"
sudo debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
sudo apt install -y postfix

# Konfigurasi Postfix
sudo postconf -e 'myhostname = mail.namaku-dot.x10.mx'
sudo postconf -e 'mydestination = $myhostname, namaku-dot.x10.mx, localhost.namaku-dot.x10.mx, localhost'
sudo postconf -e 'virtual_alias_maps = hash:/etc/postfix/virtual'

# Buat file virtual untuk Postfix
echo "@namaku-dot.x10.mx dotaja@namaku-dot.x10.mx" | sudo tee /etc/postfix/virtual
sudo postmap /etc/postfix/virtual
sudo systemctl restart postfix

# Install Dovecot
sudo apt install -y dovecot-imapd dovecot-pop3d

# Konfigurasi Dovecot
sudo sed -i 's/#protocols =/protocols = imap pop3 lmtp/' /etc/dovecot/dovecot.conf
sudo sed -i 's/#disable_plaintext_auth = yes/disable_plaintext_auth = no/' /etc/dovecot/conf.d/10-auth.conf
sudo sed -i 's/mail_location =/mail_location = maildir:~\/Maildir/' /etc/dovecot/conf.d/10-mail.conf

echo "service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0660
    user = postfix
    group = postfix
  }
}" | sudo tee -a /etc/dovecot/conf.d/10-master.conf

sudo systemctl restart dovecot

# Install Nginx dan PHP
sudo apt install -y nginx php-fpm php-imap

# Konfigurasi Nginx
echo "server {
    listen 80;
    server_name namaku-dot.x10.mx;

    root /var/www/html;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php7.2-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}" | sudo tee /etc/nginx/sites-available/default

sudo systemctl restart nginx

# Buat direktori untuk API
sudo mkdir -p /var/www/html/api

# Buat skrip PHP untuk generate email acak
echo "<?php
function generateRandomEmail(\$domain) {
    \$characters = 'abcdefghijklmnopqrstuvwxyz0123456789';
    \$email = '';
    for (\$i = 0; \$i < 10; \$i++) {
        \$email .= \$characters[rand(0, strlen(\$characters) - 1)];
    }
    return \$email . '@' . \$domain;
}

\$domain = 'namaku-dot.x10.mx';
\$randomEmail = generateRandomEmail(\$domain);

echo json_encode(['email' => \$randomEmail]);
?>" | sudo tee /var/www/html/api/generate.php

# Buat skrip PHP untuk menerima email
echo "<?php
if (!isset(\$_GET['email'])) {
    echo json_encode(['error' => 'Email parameter is required']);
    exit;
}

\$email = \$_GET['email'];
\$mailbox = imap_open('{localhost:143/imap}INBOX', 'dotaja', 'dotaja123') or die('Cannot connect: ' . imap_last_error());

\$emails = imap_search(\$mailbox, 'TO \"' . \$email . '\"');
\$response = [];

if (\$emails) {
    rsort(\$emails);
    foreach (\$emails as \$email_number) {
        \$overview = imap_fetch_overview(\$mailbox, \$email_number, 0);
        \$message = imap_fetchbody(\$mailbox, \$email_number, 2);

        \$response[] = [
            'subject' => \$overview[0]->subject,
            'from' => \$overview[0]->from,
            'message' => \$message,
        ];
    }
}

imap_close(\$mailbox);
echo json_encode(\$response);
?>" | sudo tee /var/www/html/api/receive.php

# Buat halaman index
echo "<!DOCTYPE html>
<html lang='en'>
<head>
    <meta charset='UTF-8'>
    <title>Temporary Email Service</title>
</head>
<body>
    <h1>Temporary Email Service</h1>
    <button onclick='generateEmail()'>Generate Random Email</button>
    <p id='email'></p>
    <button onclick='checkEmail()'>Check Emails</button>
    <div id='emails'></div>

    <script>
        function generateEmail() {
            fetch('/api/generate.php')
                .then(response => response.json())
                .then(data => {
                    document.getElementById('email').innerText = 'Generated Email: ' + data.email;
                    document.getElementById('email').dataset.email = data.email;
                });
        }

        function checkEmail() {
            const email = document.getElementById('email').dataset.email;
            if (!email) {
                alert('Generate an email first!');
                return;
            }

            fetch('/api/receive.php?email=' + encodeURIComponent(email))
                .then(response => response.json())
                .then(data => {
                    const emailContainer = document.getElementById('emails');
                    emailContainer.innerHTML = '';
                    if (data.error) {
                        emailContainer.innerHTML = '<p>' + data.error + '</p>';
                    } else if (data.length === 0) {
                        emailContainer.innerHTML = '<p>No emails found.</p>';
                    } else {
                        data.forEach(email => {
                            const emailDiv = document.createElement('div');
                            emailDiv.innerHTML = '<strong>From:</strong> ' + email.from + '<br>' +
                                                  '<strong>Subject:</strong> ' + email.subject + '<br>' +
                                                  '<strong>Message:</strong> ' + email.message + '<hr>';
                            emailContainer.appendChild(emailDiv);
                        });
                    }
                });
        }
    </script>
</body>
</html>" | sudo tee /var/www/html/index.php

echo "Setup selesai. Harap perbarui 'yourdomain.com' dan 'username/password' di file konfigurasi yang sesuai."
