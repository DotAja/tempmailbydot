#!/bin/bash

# Update dan instalasi paket dasar
sudo apt-get update
sudo apt-get install -y curl build-essential

# Instalasi Node Version Manager (nvm)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.4/install.sh | bash

# Muat nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Instal Node.js versi LTS terbaru
nvm install --lts
nvm use --lts

# Perbarui npm
npm install -g npm

# Instalasi paket yang dibutuhkan
sudo apt-get install -y postfix dovecot-imapd dovecot-pop3d

# Konfigurasi Postfix
sudo postconf -e 'myhostname = namaku-dot.x10.mx'
sudo postconf -e 'mydestination = namaku-dot.x10.mx, localhost'
sudo postconf -e 'home_mailbox = Maildir/'

# Restart Postfix
sudo systemctl restart postfix

# Konfigurasi Dovecot
sudo tee /etc/dovecot/conf.d/10-mail.conf > /dev/null <<EOT
mail_location = maildir:~/Maildir
EOT

sudo tee /etc/dovecot/conf.d/10-auth.conf > /dev/null <<EOT
disable_plaintext_auth = yes
auth_mechanisms = plain login
EOT

sudo tee /etc/dovecot/conf.d/10-master.conf > /dev/null <<EOT
service imap-login {
  inet_listener imap {
    port = 0
  }
  inet_listener imaps {
    port = 993
    ssl = yes
  }
}
service pop3-login {
  inet_listener pop3 {
    port = 0
  }
  inet_listener pop3s {
    port = 995
    ssl = yes
  }
}
EOT

sudo tee /etc/dovecot/conf.d/10-ssl.conf > /dev/null <<EOT
ssl = required
ssl_cert = </etc/ssl/certs/ssl-cert-snakeoil.pem
ssl_key = </etc/ssl/private/ssl-cert-snakeoil.key
EOT

# Restart Dovecot
sudo systemctl restart dovecot

# Instalasi dan konfigurasi aplikasi web
mkdir -p ~/fake-email-service
cd ~/fake-email-service

# Buat package.json untuk proyek Node.js
cat <<EOT > package.json
{
  "name": "fake-email-service",
  "version": "1.0.0",
  "description": "Temporary email service like TempM",
  "main": "app.js",
  "dependencies": {
    "express": "^4.17.1",
    "mailparser": "^2.8.1",
    "nodemailer": "^6.6.3",
    "imap": "^0.8.19"
  },
  "scripts": {
    "start": "node app.js"
  },
  "author": "",
  "license": "ISC"
}
EOT

# Instalasi dependencies
npm install

# Buat file app.js untuk aplikasi web
cat <<EOT > app.js
const express = require('express');
const Imap = require('imap');
const { MailParser } = require('mailparser');
const app = express();

app.get('/api/createmail', (req, res) => {
  const email = \`user\${Date.now()}@namaku-dot.x10.mx\`;
  res.json({ email });
});

app.get('/api/checkmail', (req, res) => {
  const email = req.query.email;
  const imapConfig = {
    user: email,
    password: 'dotaja123',
    host: 'namaku-dot.x10.mx',
    port: 993,
    tls: true
  };

  const imap = new Imap(imapConfig);

  imap.once('ready', function() {
    imap.openBox('INBOX', true, function(err, box) {
      if (err) throw err;
      imap.search(['UNSEEN', ['SINCE', new Date()]], function(err, results) {
        if (err) throw err;
        if (!results || !results.length) {
          imap.end();
          return res.json({ messages: [] });
        }

        const f = imap.fetch(results, { bodies: '' });
        const messages = [];

        f.on('message', function(msg, seqno) {
          const parser = new MailParser();
          msg.on('body', function(stream) {
            stream.pipe(parser);
          });

          parser.on('end', function(mail) {
            messages.push({ subject: mail.subject, from: mail.from, date: mail.date, text: mail.text });
          });
        });

        f.once('end', function() {
          imap.end();
          res.json({ messages });
        });
      });
    });
  });

  imap.once('error', function(err) {
    console.log(err);
    res.status(500).send(err);
  });

  imap.connect();
});

app.listen(3000, () => {
  console.log('Server berjalan di port 3000');
});
EOT

# Jalankan aplikasi web di latar belakang
nohup npm start &

echo "Layanan email sementara telah berhasil diatur dan berjalan di port 3000."
