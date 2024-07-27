#!/bin/bash

# Update dan upgrade sistem
sudo apt update
sudo apt upgrade -y

# Install Postfix dan Dovecot
sudo apt install -y postfix dovecot-imapd dovecot-pop3d

# Konfigurasi Postfix
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
sudo tee /etc/dovecot/dovecot.conf > /dev/null <<EOL
protocols = imap pop3
EOL

sudo tee /etc/dovecot/conf.d/10-mail.conf > /dev/null <<EOL
mail_location = maildir:~/Maildir
EOL

sudo tee /etc/dovecot/conf.d/10-auth.conf > /dev/null <<EOL
disable_plaintext_auth = no
auth_mechanisms = plain login
passdb {
  driver = pam
}
userdb {
  driver = passwd
}
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

# Install Python3, pip, dan virtualenv
sudo apt install -y python3-pip python3-venv

# Setup virtual environment dan instal Flask
mkdir -p ~/mail_api
cd ~/mail_api
python3 -m venv venv
source venv/bin/activate
pip install flask

# Buat aplikasi Flask
cat << 'EOF' > ~/mail_api/app.py
from flask import Flask, request, jsonify, render_template, redirect, url_for
import os

app = Flask(__name__)

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/create_email', methods=['POST'])
def create_email():
    username = request.form['username']
    home_dir = f'/home/{username}'
    
    try:
        # Buat pengguna sistem baru dengan direktori home
        os.system(f'sudo useradd -m -d {home_dir} {username}')
        
        return redirect(url_for('index'))
    except Exception as e:
        return str(e), 500

@app.route('/get_emails', methods=['GET'])
def get_emails():
    user = request.args.get('user')
    maildir = f'/home/{user}/Maildir/new'
    emails = []

    if not os.path.exists(maildir):
        return jsonify({"error": "Maildir does not exist"}), 404

    for root, dirs, files in os.walk(maildir):
        for file in files:
            if file.startswith('.'):
                continue
            try:
                with open(os.path.join(root, file), 'rb') as f:
                    msg = email.message_from_binary_file(f)
                    emails.append({
                        'subject': msg['subject'],
                        'from': msg['from'],
                        'date': msg['date'],
                        'body': msg.get_payload(decode=True).decode(errors='ignore')
                    })
            except Exception as e:
                app.logger.error(f"Failed to read email {file}: {e}")

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
        <h2>Create New Email</h2>
        <form method="post" action="/create_email">
            <input type="text" name="username" placeholder="Enter username" required/>
            <button type="submit">Create Email</button>
        </form>
        <h2>Check Emails</h2>
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
nohup ~/mail_api/venv/bin/python ~/mail_api/app.py &

echo "Setup complete. Mail server and API server are up and running. Access the web interface at http://<your-server-ip>:5000"
