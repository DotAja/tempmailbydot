#!/bin/bash

# Update and install dependencies
apt update
apt upgrade -y
apt install -y build-essential libssl-dev pkg-config nodejs npm screen

# Download and install Stalwart Mail
wget https://github.com/stalwartlabs/mail-server/releases/download/v0.8.3/stalwart-mail-x86_64-unknown-linux-gnu.tar.gz
tar -xzf stalwart-mail-x86_64-unknown-linux-gnu.tar.gz
mv stalwart-mail /usr/bin/

# Create configuration and data directories
mkdir /etc/stalwart
mkdir -p /var/lib/stalwart/mail

# Create Stalwart configuration file
cat <<EOL > /etc/stalwart/stalwart.toml
[server]
hostname = "mail.namaku-dot.x10.mx"
listen = ["0.0.0.0:25", "0.0.0.0:587"]

[domains]
"namaku-dot.x10.mx" = {}

[users]
# Users akan dibuat secara dinamis melalui API

[storage]
path = "/var/lib/stalwart/mail"
EOL

# Create project directory and initialize Node.js project in /usr/bin/
cd /usr/bin/
mkdir stalwart-api
cd stalwart-api
npm init -y
npm install express body-parser

# Create Node.js API server file
cat <<EOL > index.js
const express = require('express');
const bodyParser = require('body-parser');
const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');

const app = express();
app.use(bodyParser.json());
app.use(express.static('public'));

app.post('/create-email', (req, res) => {
    const email = \`temp_\${Date.now()}@namaku-dot.x10.mx\`;
    const password = Math.random().toString(36).slice(-8);  // Generate random password
    const command = \`stalwart adduser --email \${email} --password \${password}\`;

    exec(command, (error, stdout, stderr) => {
        if (error) {
            console.error(\`Error creating user: \${error.message}\`);
            return res.status(500).json({ error: 'Failed to create user' });
        }
        res.json({ email, password });
    });
});

const mailPath = '/var/lib/stalwart/mail';

app.get('/emails/:email', (req, res) => {
    const email = req.params.email.replace('_', '@');
    const emailPath = \`\${mailPath}/\${email.replace('@', '_')}\`;

    fs.readdir(emailPath, (err, files) => {
        if (err) {
            return res.status(500).json({ error: 'Failed to read emails' });
        }

        const emails = files.map(file => fs.readFileSync(path.join(emailPath, file), 'utf-8'));
        res.json({ emails });
    });
});

app.listen(3000, () => {
    console.log('Server running on port 3000');
});
EOL

# Create public directory and front-end files
mkdir public

# Create HTML file
cat <<EOL > public/index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Email Sementara</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <div class="container">
        <h1>Email Sementara</h1>
        <button id="generateEmailBtn">Generate Email</button>
        <div id="emailInfo"></div>
        <h2>Inbox</h2>
        <div id="inbox"></div>
    </div>
    <script src="script.js"></script>
</body>
</html>
EOL

# Create CSS file
cat <<EOL > public/style.css
body {
    font-family: Arial, sans-serif;
    background-color: #f4f4f4;
    margin: 0;
    padding: 0;
}

.container {
    max-width: 600px;
    margin: 50px auto;
    padding: 20px;
    background: white;
    box-shadow: 0 0 10px rgba(0, 0, 0, 0.1);
}

h1, h2 {
    text-align: center;
}

button {
    display: block;
    width: 100%;
    padding: 10px;
    margin-bottom: 20px;
    font-size: 16px;
    background-color: #007bff;
    color: white;
    border: none;
    cursor: pointer;
}

button:hover {
    background-color: #0056b3;
}

#emailInfo {
    margin-bottom: 20px;
    font-size: 18px;
}

#inbox {
    border-top: 1px solid #ddd;
    padding-top: 10px;
}

.email {
    padding: 10px;
    border-bottom: 1px solid #ddd;
}

.email:last-child {
    border-bottom: none;
}
EOL

# Create JavaScript file
cat <<EOL > public/script.js
document.getElementById('generateEmailBtn').addEventListener('click', generateEmail);

async function generateEmail() {
    const response = await fetch('/create-email', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        }
    });

    const data = await response.json();
    document.getElementById('emailInfo').innerHTML = \`Email: \${data.email}<br>Password: \${data.password}\`;

    checkInbox(data.email);
}

async function checkInbox(email) {
    const response = await fetch(\`/emails/\${email.replace('@', '_')}\`);
    const data = await response.json();

    const inboxDiv = document.getElementById('inbox');
    inboxDiv.innerHTML = '';

    if (data.emails.length === 0) {
        inboxDiv.innerHTML = '<p>No emails received yet.</p>';
    } else {
        data.emails.forEach(email => {
            const emailDiv = document.createElement('div');
            emailDiv.classList.add('email');
            emailDiv.textContent = email;
            inboxDiv.appendChild(emailDiv);
        });
    }
}
EOL

# Start Stalwart Mail server with screen
screen -dmS stalwart-mail /usr/bin/stalwartd -c /etc/stalwart/stalwart.toml

# Start Node.js API server with screen
screen -dmS node-api node /usr/bin/stalwart-api/index.js

echo "Setup complete. Stalwart Mail and Node.js API are running in screen sessions."
