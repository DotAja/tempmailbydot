#!/bin/bash

# Perbarui dan upgrade sistem
sudo apt update && sudo apt upgrade -y

# Instal Postfix
sudo apt install postfix python3-pip -y

# Konfigurasi Postfix
sudo debconf-set-selections <<< "postfix postfix/mailname string test.dot-store.x10.bz"
sudo debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
sudo dpkg-reconfigure -f noninteractive postfix

# Konfigurasi file main.cf
sudo bash -c "cat <<EOL >> /etc/postfix/main.cf
myhostname = mail.test.dot-store.x10.bz
mydomain = test.dot-store.x10.bz
myorigin = \$mydomain
mydestination = \$myhostname, localhost.\$mydomain, localhost, \$mydomain
relay_domains = \$mydestination
inet_interfaces = all
virtual_alias_maps = hash:/etc/postfix/virtual
EOL"

# Buat file virtual dan tambahkan alamat
sudo bash -c "cat <<EOL > /etc/postfix/virtual
@test.dot-store.x10.bz test.dot-store.x10.bz
EOL"

# Generate database untuk virtual
sudo postmap /etc/postfix/virtual

# Restart Postfix
sudo systemctl restart postfix

# Buat skrip Python untuk menangani email yang masuk
sudo bash -c "cat <<'EOL' > /home/$USER/handle_email.py
import sys
import email
import os

def save_email(raw_email):
    msg = email.message_from_bytes(raw_email)
    email_address = msg['To']
    email_body = msg.get_payload(decode=True).decode()

    # Simpan email ke file atau database
    with open(f'/var/tmp/{email_address}.txt', 'a') as f:
        f.write(f"From: {msg['From']}\n")
        f.write(f"Subject: {msg['Subject']}\n")
        f.write(f"Body: {email_body}\n")
        f.write("\n" + "="*50 + "\n\n")

if __name__ == "__main__":
    raw_email = sys.stdin.read().encode()
    save_email(raw_email)
EOL"

# Berikan izin eksekusi pada skrip
chmod +x /home/$USER/handle_email.py

# Edit file aliases
sudo bash -c "cat <<EOL >> /etc/aliases
test.dot-store.x10.bz: \"/home/$USER/handle_email.py\"
EOL"

# Reload aliases
sudo newaliases

# Instal Flask
pip3 install Flask

# Buat file Flask app.py
sudo bash -c "cat <<'EOL' > /home/$USER/app.py
from flask import Flask, request, jsonify
import random
import string
import os

app = Flask(__name__)

# Fungsi untuk menghasilkan email sementara
def generate_email():
    username = ''.join(random.choices(string.ascii_lowercase + string.digits, k=10))
    return f"{username}@test.dot-store.x10.bz"

@app.route('/get-email')
def get_email():
    email = generate_email()
    # Buat file kosong untuk menyimpan email yang diterima
    open(f'/var/tmp/{email}.txt', 'w').close()
    return jsonify({'email': email})

@app.route('/check-email')
def check_email():
    email = request.args.get('email')
    if os.path.exists(f'/var/tmp/{email}.txt'):
        with open(f'/var/tmp/{email}.txt', 'r') as f:
            emails = f.read().split("="*50)
            emails = [e.strip() for e in emails if e.strip()]
        return jsonify({'emails': emails})
    return jsonify({'emails': []})

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0')
EOL"

# Buat file HTML index.html
sudo bash -c "cat <<'EOL' > /home/$USER/index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Temp Mail</title>
</head>
<body>
    <h1>Temp Mail</h1>
    <button onclick="getEmail()">Get Temporary Email</button>
    <p id="email"></p>
    <h2>Received Emails</h2>
    <ul id="emails"></ul>

    <script>
        function getEmail() {
            fetch('/get-email')
                .then(response => response.json())
                .then(data => {
                    document.getElementById('email').innerText = data.email;
                    checkEmails(data.email);
                });
        }

        function checkEmails(email) {
            setInterval(() => {
                fetch(`/check-email?email=${email}`)
                    .then(response => response.json())
                    .then(data => {
                        const emailList = document.getElementById('emails');
                        emailList.innerHTML = '';
                        data.emails.forEach(email => {
                            const li = document.createElement('li');
                            li.innerText = email;
                            emailList.appendChild(li);
                        });
                    });
            }, 5000); // Check every 5 seconds
        }
    </script>
</body>
</html>
EOL"

# Instruksi untuk menjalankan Flask app
echo "Gunakan 'python3 /home/$USER/app.py' untuk menjalankan server Flask."
echo "Buka browser dan akses 'http://localhost:5000' untuk melihat aplikasi Temp Mail."

echo "Selesai!"
