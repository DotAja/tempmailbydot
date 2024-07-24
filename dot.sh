#!/bin/bash

# Minta input manual untuk server email
echo "=== Konfigurasi Server Email ==="
read -p "Masukkan domain utama (contoh: yourdomain.com): " MAIN_DOMAIN
read -p "Masukkan hostname untuk mail server (contoh: mail.yourdomain.com): " MAIL_HOSTNAME

# Instalasi dan konfigurasi server email
echo "Menginstal dan mengonfigurasi server email..."
sudo apt-get update
sudo apt-get install -y postfix dovecot-core dovecot-imapd dovecot-pop3d

# Konfigurasi Postfix
sudo tee /etc/postfix/main.cf > /dev/null <<EOF
myhostname = $MAIL_HOSTNAME
myorigin = \$mydomain
mydestination = \$myhostname, localhost.\$mydomain, localhost, \$mydomain
virtual_alias_domains = \$mydomain
virtual_alias_maps = hash:/etc/postfix/virtual
EOF

# Buat konfigurasi virtual
sudo tee /etc/postfix/virtual > /dev/null <<EOF
@*.$MAIN_DOMAIN tempmailuser@$MAIN_DOMAIN
EOF

# Generate hash database
sudo postmap /etc/postfix/virtual

# Restart Postfix
sudo systemctl restart postfix

# Konfigurasi Dovecot
sudo tee /etc/dovecot/dovecot.conf > /dev/null <<EOF
protocols = imap pop3
mail_location = maildir:~/Maildir
EOF

# Restart Dovecot
sudo systemctl restart dovecot

echo "Server email telah dikonfigurasi dengan domain $MAIN_DOMAIN dan hostname $MAIL_HOSTNAME."

# Minta input manual untuk API server
echo "=== Konfigurasi API Server ==="
read -p "Masukkan port API server (contoh: 3000): " API_PORT

# Instalasi dan konfigurasi API server
echo "Menginstal dan mengonfigurasi API server..."
sudo apt-get install -y nodejs npm

# Buat direktori untuk API
mkdir -p ~/mx-record-api
cd ~/mx-record-api

# Inisialisasi proyek Node.js dan install dependensi
npm init -y
npm install express dns cors crypto

# Buat file server.js
cat << EOF > server.js
const express = require('express');
const dns = require('dns');
const cors = require('cors');
const crypto = require('crypto');
const app = express();
const port = $API_PORT;

app.use(cors());
app.use(express.json());

const tempEmails = {};

app.get('/mx-records', (req, res) => {
  const domain = req.query.domain;
  if (!domain) {
    return res.status(400).json({ error: 'Domain query parameter is required' });
  }

  dns.resolveMx(domain, (err, records) => {
    if (err) {
      return res.status(500).json({ error: err.message });
    }
    res.json(records);
  });
});

app.post('/create-email', (req, res) => {
  const { domain } = req.body;
  if (!domain) {
    return res.status(400).json({ error: 'Domain is required' });
  }

  dns.resolveMx(domain, (err, records) => {
    if (err || records.length === 0) {
      return res.status(400).json({ error: 'Invalid domain' });
    }

    const email = \`temp-\${crypto.randomBytes(4).toString('hex')}@\${domain}\`;
    tempEmails[email] = domain;
    res.json({ email });
  });
});

app.get('/check-email/:email', (req, res) => {
  const { email } = req.params;
  if (tempEmails[email]) {
    res.json({ exists: true });
  } else {
    res.json({ exists: false });
  }
});

app.listen(port, () => {
  console.log(\`Server is running on port \${port}\`);
});
EOF

# Jalankan server Node.js
nohup node server.js > ~/mx-record-api/server.log 2>&1 &
echo "API server telah dijalankan pada port $API_PORT."

# Minta input manual untuk frontend
echo "=== Konfigurasi Frontend ==="
read -p "Masukkan domain untuk frontend (contoh: yourdomain.com): " FRONTEND_DOMAIN
read -p "Masukkan IP server API (contoh: 127.0.0.1): " API_IP
read -p "Masukkan port API server (contoh: 3000): " API_PORT

# Instalasi dan konfigurasi frontend
echo "Menginstal dan mengonfigurasi frontend..."
sudo apt-get install -y nginx

# Buat direktori untuk frontend
sudo mkdir -p /var/www/html/fakemail
cd /var/www/html/fakemail

# Buat file index.html
cat << EOF > index.html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>FakeMail</title>
  <link rel="stylesheet" href="styles.css">
</head>
<body>
  <header>
    <h1>FakeMail</h1>
    <nav>
      <ul>
        <li><a href="#">Home</a></li>
        <li><a href="#">About</a></li>
        <li><a href="#">Contact</a></li>
      </ul>
    </nav>
  </header>
  <main>
    <section id="email-form">
      <h2>Create Temporary Email</h2>
      <form id="emailForm">
        <label for="domain">Domain:</label>
        <input type="text" id="domain" name="domain" required>
        <button type="submit">Generate Email</button>
      </form>
      <div id="result"></div>
    </section>
  </main>
  <footer>
    <p>&copy; 2024 FakeMail. All rights reserved.</p>
  </footer>
  <script src="script.js"></script>
</body>
</html>
EOF

# Buat file script.js
cat << EOF > script.js
document.getElementById('emailForm').addEventListener('submit', function(event) {
  event.preventDefault();

  const domain = document.getElementById('domain').value;
  const resultDiv = document.getElementById('result');

  fetch('http://$API_IP:$API_PORT/create-email', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ domain })
  })
    .then(response => response.json())
    .then(data => {
      if (data.email) {
        resultDiv.innerHTML = '<p>Your temporary email is: ' + data.email + '</p>';
      } else {
        resultDiv.innerHTML = '<p>Failed to create email: ' + data.error + '</p>';
      }
    })
    .catch(error => {
      resultDiv.innerHTML = '<p>Failed to create email: ' + error.message + '</p>';
    });
});
EOF

# Konfigurasi Nginx
sudo tee /etc/nginx/sites-available/fakemail > /dev/null <<EOF
server {
    listen 80;
    server_name $FRONTEND_DOMAIN;

    root /var/www/html/fakemail;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

# Aktifkan konfigurasi Nginx dan restart Nginx
sudo ln -s /etc/nginx/sites-available/fakemail /etc/nginx/sites-enabled/
sudo systemctl restart nginx

echo "Frontend telah dikonfigurasi dengan domain $FRONTEND_DOMAIN dan API IP $API_IP:$API_PORT."

# Menjadwalkan skrip agar otomatis dijalankan saat boot
echo "Menambahkan skrip ke cron @reboot..."
CRON_JOB="@reboot /usr/bin/setup-all-in-one.sh"
(crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

echo "Setup selesai. Skrip akan dijalankan saat boot."
