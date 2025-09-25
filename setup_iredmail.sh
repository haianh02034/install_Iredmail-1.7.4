#!/bin/bash
# One-shot setup for iRedMail on Ubuntu 22.04 / 24.04
# Author: ChatGPT

MAIL_HOST="mail.domain"
DOMAIN="domain"
IREDMAIL_VER="1.7.4"   # đổi nếu có version mới
IREDMAIL_URL="https://github.com/iredmail/iRedMail/archive/refs/tags/${IREDMAIL_VER}.tar.gz"

# --- Kiểm tra root ---
if [ "$EUID" -ne 0 ]; then
  echo "❌ Hãy chạy script bằng root (sudo su -)"
  exit 1
fi

# --- Kiểm tra OS ---
if ! grep -q "Ubuntu" /etc/os-release; then
  echo "❌ Script này chỉ dành cho Ubuntu 22.04/24.04"
  exit 1
fi

echo "✅ Bắt đầu cài đặt iRedMail cho $MAIL_HOST"

# --- Đặt hostname ---
hostnamectl set-hostname "$MAIL_HOST"
if ! grep -q "$MAIL_HOST" /etc/hosts; then
  echo "127.0.0.1   $MAIL_HOST mail localhost" >> /etc/hosts
fi
echo "✅ Hostname set thành $MAIL_HOST"

# --- Cập nhật hệ thống ---
apt update && apt -y upgrade
apt install -y wget curl ufw lsb-release net-tools

# --- Cấu hình firewall ---
ufw allow OpenSSH
for p in 25 587 465 143 993 110 995 80 443; do
  ufw allow $p/tcp
done
ufw --force enable
echo "✅ Firewall mở port mail + web"

# --- Tải và giải nén iRedMail ---
cd /root
wget -O "iRedMail-${IREDMAIL_VER}.tar.gz" "$IREDMAIL_URL"
tar xvf "iRedMail-${IREDMAIL_VER}.tar.gz"
cd "iRedMail-${IREDMAIL_VER}"
chmod +x iRedMail.sh

echo "✅ Đã tải iRedMail $IREDMAIL_VER"
echo "👉 Bây giờ hãy chạy:   bash iRedMail.sh"
echo "   và làm theo wizard (chọn Nginx, MariaDB, domain $DOMAIN, admin email, v.v.)"

# --- Chuẩn bị Certbot (Let's Encrypt) ---
apt install -y certbot
echo
echo "✅ Certbot đã sẵn sàng."
echo "Sau khi iRedMail cài xong và Nginx chạy, hãy cấp SSL bằng:"
echo "   certbot certonly --webroot -w /var/www/html -d $MAIL_HOST -d $DOMAIN"
echo "   ln -sf /etc/letsencrypt/live/$MAIL_HOST/fullchain.pem /etc/ssl/iRedMail.crt"
echo "   ln -sf /etc/letsencrypt/live/$MAIL_HOST/privkey.pem /etc/ssl/iRedMail.key"
echo "   systemctl restart postfix dovecot nginx amavis"
echo
echo "🎉 Script hoàn tất. Tiếp theo bạn hãy chạy iRedMail installer."
