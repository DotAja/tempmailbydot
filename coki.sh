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

printf "service auth {\n  unix_listener /var/spool/postfix/private/auth {\n    mode = 0660\n    user = postfix\n    group = postfix\n  }\n}\n" | sudo tee -a /etc/dovecot/conf.d/10-master.conf

sudo systemctl restart dovecot

# Install Nginx dan PHP
sudo apt install -y nginx php-fpm php-imap

# Konfigurasi Nginx
printf "server {\n    listen 80;\n    server_name namaku-dot.x10.mx;\n\n    root /var/www/html;\n    index index.php index.html index.htm;\n\n    location / {\n        try_files \$uri \$uri/ =404;\n    }\n\n    location ~ \\.php\$ {\n        include snippets/fastcgi-php.conf;\n        fastcgi_pass unix:/var/run/php/php7.2-fpm.sock;\n        fastcgi_index index.php;\n        include fastcgi_params;\n    }\n\n    location ~ /\\.ht {\n        deny all;\n    }\n}\n" | sudo tee /etc/nginx/sites-available/default

sudo systemctl restart nginx

# Buat direktori untuk API
sudo mkdir -p /var/www/html/api

# Buat skrip PHP untuk generate email acak
printf "<?php\nfunction generateRandomEmail(\$domain) {\n    \$characters = 'abcdefghijklmnopqrstuvwxyz0123456789';\n    \$email = '';\n    for (\$i = 0; \$i < 10; \$i++) {\n        \$email .= \$characters[rand(0, strlen(\$characters) - 1)];\n    }\n    return \$email . '@' . \$domain;\n}\n\n\$domain = 'namaku-dot.x10.mx';\n\$randomEmail = generateRandomEmail(\$domain);\n\necho json_encode(['email' => \$randomEmail]);\n?>" | sudo tee /var/www/html/api/generate.php

# Buat skrip PHP untuk menerima email
printf "<?php\nif (!isset(\$_GET['email'])) {\n    echo json_encode(['error' => 'Email parameter is required']);\n    exit;\n}\n\n\$email = \$_GET['email'];\n\$mailbox = imap_open('{localhost:143/imap}INBOX', 'dotaja', 'dotaja123') or die('Cannot connect: ' . imap_last_error());\n\n\$emails = imap_search(\$mailbox, 'TO \"' . \$email . '\"');\n\$response = [];\n\nif (\$emails) {\n    rsort(\$emails);\n    foreach (\$emails as \$email_number) {\n        \$overview = imap_fetch_overview(\$mailbox, \$email_number, 0);\n        \$message = imap_fetchbody(\$mailbox, \$email_number, 2);\n\n        \$response[] = [\n            'subject' => \$overview[0]->subject,\n            'from' => \$overview[0]->from,\n            'message' => \$message,\n        ];\n    }\n}\n\nimap_close(\$mailbox);\necho json_encode(\$response);\n?>" | sudo tee /var/www/html/api/receive.php

# Buat halaman index
printf "<!DOCTYPE html>\n<html lang='en'>\n<head>\n    <meta charset='UTF-8'>\n    <title>Temporary Email Service</title>\n</head>\n<body>\n    <h1>Temporary Email Service</h1>\n    <button onclick='generateEmail()'>Generate Random Email</button>\n    <p id='email'></p>\n    <button onclick='checkEmail()'>Check Emails</button>\n    <div id='emails'></div>\n\n    <script>\n        function generateEmail() {\n            fetch('/api/generate.php')\n                .then(response => response.json())\n                .then(data => {\n                    document.getElementById('email').innerText = 'Generated Email: ' + data.email;\n                    document.getElementById('email').dataset.email = data.email;\n                });\n        }\n\n        function checkEmail() {\n            const email = document.getElementById('email').dataset.email;\n            if (!email) {\n                alert('Generate an email first!');\n                return;\n            }\n\n            fetch('/api/receive.php?email=' + encodeURIComponent(email))\n                .then(response => response.json())\n                .then(data => {\n                    const emailContainer = document.getElementById('emails');\n                    emailContainer.innerHTML = '';\n                    if (data.error) {\n                        emailContainer.innerHTML = '<p>' + data.error + '</p>';\n                    } else if (data.length === 0) {\n                        emailContainer.innerHTML = '<p>No emails found.</p>';\n                    } else {\n                        data.forEach(email => {\n                            const emailDiv = document.createElement('div');\n                            emailDiv.innerHTML = '<strong>From:</strong> ' + email.from + '<br>' +\n                                                  '<strong>Subject:</strong> ' + email.subject + '<br>' +\n                                                  '<strong>Message:</strong> ' + email.message + '<hr>';\n                            emailContainer.appendChild(emailDiv);\n                        });\n                    }\n                });\n        }\n    </script>\n</body>\n</html>" | sudo tee /var/www/html/index.php

echo "Setup selesai. Harap perbarui 'yourdomain.com' dan 'username/password' di file konfigurasi yang sesuai."
