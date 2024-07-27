#!/bin/bash

# Update dan upgrade sistem
echo "Updating and upgrading the system..."
sudo apt update
sudo apt upgrade -y

# Install Postfix dan Dovecot
echo "Installing Postfix and Dovecot..."
sudo apt install -y postfix dovecot-imapd dovecot-pop3d

# Konfigurasi Postfix
echo "Configuring Postfix..."
sudo tee /etc/postfix/main.cf > /dev/null <<EOL
myhostname = namaku-dot.x10.mx
mydomain = namaku-dot.x10.mx
myorigin = \$mydomain
inet_interfaces = all
mydestination = \$myhostname, localhost.\$mydomain, localhost, \$mydomain
home_mailbox = Maildir/
EOL

sudo systemctl restart postfix

# Konfigurasi Dovecot
echo "Configuring Dovecot..."
sudo tee /etc/dovecot/dovecot.conf > /dev/null <<EOL
protocols = imap pop3
EOL

sudo tee /etc/dovecot/conf.d/10-mail.conf > /dev/null <<EOL
mail_location = maildir:~/Maildir
EOL

sudo tee /etc/dovecot/conf.d/10-auth.conf > /dev/null <<EOL
disable_plaintext_auth = no
EOL

sudo tee /etc/dovecot/conf.d/10-master.conf > /dev/null <<EOL
service imap-login {
  inet_listener imap {
    port = 143
  }
}

service pop3-login {
  inet_listener pop3 {
    port = 110
  }
}
EOL

sudo systemctl restart dovecot

# Install Python3 dan Flask
echo "Installing Python3, pip, and Flask..."
sudo apt install -y python3-pip
pip3 install flask

# Setup API server dan antarmuka web
echo "Setting up API server and web interface..."
mkdir -p ~/mail_api
cat << 'EOF' > ~/mail_api/app.py
from flask import Flask, request, jsonify, render_template
import os
import email
from email.parser import BytesParser
from email.policy import default

app = Flask(__name__)

@app.route('/')
def index():
    return render_template('index.html')

# Endpoint untuk mendapatkan daftar email
@app.route('/get_emails', methods=['GET'])
def get_emails():
    user = request.args.get('user')
    maildir = f'/home/{user}/Maildir'
    emails = []

    for root, dirs, files in os.walk(maildir):
        for file in files:
            if file.startswith('.'):
                continue
            with open(os.path.join(root, file), 'rb') as f:
                msg = BytesParser(policy=default).parse(f)
                emails.append({
                    'subject': msg['subject'],
                    'from': msg['from'],
                    'date': msg['date'],
                    'body': msg.get_payload(decode=True).decode(errors='ignore')
                })

    return jsonify(emails), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
EOF

# Buat direktori templates untuk menyimpan file HTML
mkdir -p ~/mail_api/templates
cat << 'EOF' > ~/mail_api/templates/index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Temporary Email</title>
    <style>
        body { font-family: Arial, sans-serif; }
        .container { width: 80%; margin: auto; padding: 20px; }
        table { width: 100%; border-collapse: collapse; }
        table, th, td { border: 1px solid black; }
        th, td { padding: 10px; text-align: left; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Temporary Email</h1>
        <input type="text" id="username" placeholder="Enter username" />
        <button onclick="fetchEmails()">Fetch Emails</button>
        <table id="emailsTable">
            <thead>
                <tr>
                    <th>From</th>
                    <th>Subject</th>
                    <th>Date</th>
                    <th>Body</th>
                </tr>
            </thead>
            <tbody>
            </tbody>
        </table>
    </div>
    <script>
        function fetchEmails() {
            const username = document.getElementById('username').value;
            fetch(`/get_emails?user=${username}`)
                .then(response => response.json())
                .then(emails => {
                    const tableBody = document.getElementById('emailsTable').getElementsByTagName('tbody')[0];
                    tableBody.innerHTML = '';
                    emails.forEach(email => {
                        const row = tableBody.insertRow();
                        row.insertCell(0).innerText = email.from;
                        row.insertCell(1).innerText = email.subject;
                        row.insertCell(2).innerText = email.date;
                        row.insertCell(3).innerText = email.body;
                    });
                });
        }
    </script>
</body>
</html>
EOF

# Jalankan API server di latar belakang
echo "Starting API server..."
nohup python3 ~/mail_api/app.py &

echo "Setup complete. Mail server and API server are up and running. Access the web interface at http://<your-server-ip>:5000"
