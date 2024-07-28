#!/bin/bash

# Masukkan domain dan subdomain yang akan digunakan
DOMAIN="kontol.dot.x10.bz"
SUBDOMAIN="mail.kontol.dot.x10.bz"

# Update dan install Postfix dan Dovecot
sudo apt update
sudo apt install -y postfix dovecot-core dovecot-imapd curl

# Konfigurasi Postfix
sudo postconf -e "myhostname = $SUBDOMAIN"
sudo postconf -e "mydestination = \$myhostname, $DOMAIN, $SUBDOMAIN, localhost"
sudo postconf -e "virtual_alias_maps = hash:/etc/postfix/virtual"
sudo postconf -e "relay_domains = $DOMAIN, $SUBDOMAIN"

# Buat file virtual dan tambahkan pengguna virtual
echo "user@$SUBDOMAIN user-mailbox" | sudo tee /etc/postfix/virtual

# Apply virtual map
sudo postmap /etc/postfix/virtual

# Restart Postfix
sudo systemctl restart postfix

# Konfigurasi Dovecot
sudo bash -c 'cat > /etc/dovecot/dovecot.conf <<EOF
protocols = imap
EOF'

sudo bash -c 'cat > /etc/dovecot/conf.d/10-mail.conf <<EOF
mail_location = maildir:~/Maildir
EOF'

# Restart Dovecot
sudo systemctl restart dovecot

# Install Node.js dan Express
curl -sL https://deb.nodesource.com/setup_14.x | sudo -E bash -
sudo apt install -y nodejs

# Buat proyek Node.js
mkdir ~/temp-email-api
cd ~/temp-email-api
npm init -y
npm install express

# Buat server API
cat > server.js <<EOF
const express = require('express');
const { exec } = require('child_process');
const app = express();
const port = 3000;

app.use(express.json());

app.post('/generate-email', (req, res) => {
    const domain = req.body.domain;
    const email = 'user' + Math.floor(Math.random() * 1000) + '@' + domain;
    res.json({ email });
});

app.post('/messages', (req, res) => {
    const email = req.body.email;
    const user = email.split('@')[0];

    // Contoh sederhana untuk membaca maildir, perlu penyesuaian lebih lanjut
    exec(\`grep -r '' /home/\${user}/Maildir\`, (err, stdout, stderr) => {
        if (err) {
            return res.status(500).json({ error: 'Failed to retrieve messages' });
        }

        const messages = stdout.split('\\n').map(line => {
            // Parsing sederhana, perlu disesuaikan dengan format email sebenarnya
            const parts = line.split(':');
            return { from: parts[0], subject: parts[1], body: parts.slice(2).join(':') };
        });

        res.json({ messages });
    });
});

app.get('/domains', (req, res) => {
    // Menyediakan daftar subdomain yang digunakan
    const domains = ['mail.kontol.dot.x10.bz']; // Tambahkan subdomain yang relevan
    res.json({ domains });
});

app.listen(port, () => {
    console.log(\`Server is running on http://localhost:\${port}\`);
});
EOF

# Jalankan server API
node server.js &
