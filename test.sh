#!/bin/bash

# Update dan upgrade sistem
sudo apt update && sudo apt upgrade -y

# Instalasi Apache dan PHP
sudo apt install -y apache2 php libapache2-mod-php

# Instalasi dan konfigurasi Postfix
sudo apt install -y postfix
sudo debconf-set-selections <<< "postfix postfix/mailname string mail.dot-store.x10.bz"
sudo debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
sudo sed -i "s/#myhostname = host.domain.tld/myhostname = mail.dot-store.x10.bz/" /etc/postfix/main.cf
sudo sed -i "s/#mydomain = domain.tld/mydomain = dot-store.x10.bz/" /etc/postfix/main.cf
sudo sed -i "s/#myorigin = \$mydomain/myorigin = \$mydomain/" /etc/postfix/main.cf
sudo sed -i "s/#inet_interfaces = all/inet_interfaces = all/" /etc/postfix/main.cf
sudo sed -i "s/#mydestination = \$myhostname, localhost.\$mydomain, localhost/mydestination = \$myhostname, localhost.\$mydomain, localhost/" /etc/postfix/main.cf

# Tambahkan domain tambahan ke Postfix
sudo tee -a /etc/postfix/main.cf <<EOF
virtual_mailbox_domains = dot-store.x10.bz
virtual_mailbox_base = /var/mail/vhosts
virtual_mailbox_maps = hash:/etc/postfix/virtual_mailbox
virtual_alias_maps = hash:/etc/postfix/virtual_alias
EOF

# Buat direktori untuk mailboxes dan sesuaikan izin
sudo mkdir -p /var/mail/vhosts
sudo chown -R postfix:postfix /var/mail/vhosts
sudo chmod -R 700 /var/mail/vhosts

# Konfigurasi file virtual_mailbox dan virtual_alias
sudo tee /etc/postfix/virtual_mailbox <<EOF
user1@dot-store.x10.bz user1/
EOF

sudo tee /etc/postfix/virtual_alias <<EOF
info@dot-store.x10.bz user1@dot-store.x10.bz
EOF

# Buat database hash untuk Postfix
sudo postmap /etc/postfix/virtual_mailbox
sudo postmap /etc/postfix/virtual_alias

# Instalasi dan konfigurasi Dovecot
sudo apt install -y dovecot-core dovecot-imapd dovecot-pop3d
sudo sed -i "s/#mail_location = maildir:~\/Maildir/mail_location = maildir:~\/Maildir/" /etc/dovecot/conf.d/10-mail.conf
sudo sed -i "s/#mail_privileged_group = mail/mail_privileged_group = mail/" /etc/dovecot/conf.d/10-master.conf
sudo sed -i "s/#listen = \*listen = 0.0.0.0, ::/" /etc/dovecot/dovecot.conf
sudo systemctl restart dovecot

# Buat folder untuk menyimpan email sementara
sudo mkdir -p /var/mail/vhosts/dot-store.x10.bz
sudo chown -R vmail:vmail /var/mail/vhosts

# Buat folder untuk webmail
sudo mkdir -p /var/www/html/webmail
sudo chown -R www-data:www-data /var/www/html/webmail

# Buat file index.html untuk webmail
cat <<EOF | sudo tee /var/www/html/webmail/index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Webmail - Inbox</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 0;
            background-color: #f4f4f4;
        }
        .container {
            width: 80%;
            margin: 0 auto;
            padding: 20px;
        }
        .email-form, .email-list {
            margin-bottom: 20px;
        }
        .email-form input[type="text"] {
            padding: 10px;
            margin-bottom: 10px;
        }
        .email-form input[type="submit"] {
            padding: 10px;
            background-color: #007bff;
            border: none;
            color: white;
            cursor: pointer;
        }
        .email-form input[type="submit"]:hover {
            background-color: #0056b3;
        }
        .email-list {
            list-style-type: none;
            padding: 0;
        }
        .email-list li {
            padding: 10px;
            border-bottom: 1px solid #ddd;
        }
        .email-list li:hover {
            background-color: #e9ecef;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Webmail</h1>
        <div class="email-form">
            <h2>Buat Email Sementara</h2>
            <form id="createEmailForm">
                <input type="text" id="emailAddress" placeholder="Masukkan nama untuk email" required>
                <input type="submit" value="Buat Email">
            </form>
        </div>
        <div class="email-form">
            <h2>Inbox</h2>
            <ul id="emailList" class="email-list"></ul>
        </div>
    </div>
    <script src="webmail.js"></script>
</body>
</html>
EOF

# Buat file webmail.js untuk JavaScript
cat <<EOF | sudo tee /var/www/html/webmail/webmail.js
document.addEventListener('DOMContentLoaded', function() {
    document.getElementById('createEmailForm').addEventListener('submit', function(event) {
        event.preventDefault();

        const emailName = document.getElementById('emailAddress').value;
        const domain = 'dot-store.x10.bz'; // Domain email sementara

        const email = \`\${emailName}@\${domain}\`;

        // Kirim permintaan ke server untuk membuat email
        fetch('/create_email.php', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ email })
        })
        .then(response => response.json())
        .then(data => {
            alert(data.message);
            loadEmails(); // Muat email setelah membuat alamat
        })
        .catch(error => console.error('Error:', error));
    });

    loadEmails();
});

function loadEmails() {
    fetch('/get_emails.php')
    .then(response => response.json())
    .then(emails => {
        const emailList = document.getElementById('emailList');
        emailList.innerHTML = '';
        emails.forEach(email => {
            const li = document.createElement('li');
            li.textContent = \`Dari: \${email.from} - Subjek: \${email.subject} - \${email.date}\`;
            emailList.appendChild(li);
        });
    })
    .catch(error => console.error('Error:', error));
}
EOF

# Buat file create_email.php untuk PHP
cat <<EOF | sudo tee /var/www/html/webmail/create_email.php
<?php
// create_email.php

header('Content-Type: application/json');

// Ambil data dari permintaan POST
$data = json_decode(file_get_contents('php://input'), true);
$email = $data['email'];

// Path untuk menyimpan email sementara
$path = '/var/mail/vhosts/' . explode('@', $email)[1] . '/' . $email;

// Buat file kosong untuk email
if (!file_exists($path)) {
    file_put_contents($path, "From: example@example.com\nSubject: Example Subject\nDate: " . date('r'));
    echo json_encode(['message' => 'Email berhasil dibuat']);
} else {
    echo json_encode(['message' => 'Email sudah ada']);
}
?>
EOF

# Buat file get_emails.php untuk PHP
cat <<EOF | sudo tee /var/www/html/webmail/get_emails.php
<?php
// get_emails.php

header('Content-Type: application/json');

// Path ke folder inbox email
$emailDir = '/var/mail/vhosts'; // Ganti dengan path folder email yang sesuai

$emails = [];
if (is_dir($emailDir)) {
    $domains = array_diff(scandir($emailDir), array('.', '..'));
    foreach ($domains as $domain) {
        $domainPath = $emailDir . '/' . $domain;
        if (is_dir($domainPath)) {
            $files = array_diff(scandir($domainPath), array('.', '..'));
            foreach ($files as $file) {
                $filePath = $domainPath . '/' . $file;
                if (is_file($filePath)) {
                    $emailContent = file_get_contents($filePath);
                    // Asumsi format email
                    $headers = explode("\n", $emailContent);
                    $from = '';
                    $subject = '';
                    $date = '';
                    foreach ($headers as $header) {
                        if (stripos($header, 'From:') === 0) {
                            $from = trim(substr($header, 5));
                        } elseif (stripos($header, 'Subject:') === 0) {
                            $subject = trim(substr($header, 8));
                        } elseif (stripos($header, 'Date:') === 0) {
                            $date = trim(substr($header, 5));
                        }
                    }
                    $emails[] = [
                        'from' => $from,
                        'subject' => $subject,
                        'date' => $date
                    ];
                }
            }
        }
    }
}

// Output JSON
echo json_encode($emails);
?>
EOF

# Konfigurasi Firewall
sudo ufw allow 25/tcp
sudo ufw allow 143/tcp
sudo ufw allow 993/tcp
sudo ufw enable

# Restart layanan untuk menerapkan semua perubahan
sudo systemctl restart postfix
sudo systemctl restart dovecot
sudo systemctl restart apache2

echo "Instalasi dan konfigurasi selesai. Akses webmail di http://your_server_ip/webmail/"
echo "Pastikan DNS MX dan A records telah diatur dengan benar untuk domain kamu."
echo "Jangan lupa untuk memeriksa firewall dan pastikan port email terbuka."
