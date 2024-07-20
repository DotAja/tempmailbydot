#!/bin/bash

# Fungsi untuk menampilkan pesan dan keluar jika terjadi kesalahan
function error_exit {
  echo "$1" 1>&2
  exit 1
}

# Update daftar paket dan instal paket pendukung
sudo apt update || error_exit "Gagal memperbarui daftar paket!"
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common || error_exit "Gagal menginstal paket pendukung!"

# Tambahkan GPG key untuk Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - || error_exit "Gagal menambahkan GPG key untuk Docker!"

# Tambahkan repository Docker ke APT sources
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" || error_exit "Gagal menambahkan repository Docker!"

# Update daftar paket lagi
sudo apt update || error_exit "Gagal memperbarui daftar paket!"

# Instal Docker
sudo apt install -y docker-ce || error_exit "Gagal menginstal Docker!"

# Verifikasi instalasi Docker
sudo systemctl status docker || error_exit "Docker tidak berjalan!"

# Instal Docker Compose
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -Po 'tag_name": "\K[0-9.]+')
sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose || error_exit "Gagal mengunduh Docker Compose!"
sudo chmod +x /usr/local/bin/docker-compose || error_exit "Gagal mengatur izin eksekusi pada Docker Compose!"

# Verifikasi instalasi Docker Compose
docker-compose --version || error_exit "Docker Compose tidak terinstal dengan benar!"

# Unduh template konfigurasi Mailu
curl -L https://setup.mailu.io/1.8/ > mailu.env || error_exit "Gagal mengunduh template konfigurasi Mailu!"

# Edit file mailu.env sesuai kebutuhan (Anda dapat menambahkan lebih banyak penyesuaian di sini)
sed -i 's/DOMAIN=mailu.io/DOMAIN=yourdomain.com/' mailu.env
sed -i 's/TZ=UTC/TZ=Asia/Jakarta/' mailu.env

# Unduh file docker-compose.yml
curl -L https://raw.githubusercontent.com/Mailu/Mailu/1.8/docker-compose.yml > docker-compose.yml || error_exit "Gagal mengunduh docker-compose.yml!"

# Jalankan Mailu
docker-compose up -d || error_exit "Gagal menjalankan Mailu!"

echo "Mailu berhasil diinstal dan dijalankan!"
echo "Akses webmail Anda melalui subdomain yang sesuai."
