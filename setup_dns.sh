#!/bin/bash
# auto-letsencrypt-iredmail.sh (không dùng API DNS)

DOMAIN="domain"
EMAIL="postmaster@$DOMAIN"
WEBROOT="/var/www/html"

echo "[INFO] Cập nhật hệ thống và cài Certbot..."
apt update
apt install -y certbot python3-certbot-nginx

# 1️⃣ Tạo webroot
echo "[INFO] Tạo webroot nếu chưa có..."
mkdir -p $WEBROOT
chown www-data:www-data $WEBROOT

# 2️⃣ Cấp chứng chỉ Let's Encrypt
echo "[INFO] Cấp chứng chỉ Let's Encrypt..."
certbot certonly --webroot -w $WEBROOT -d $DOMAIN -d mail.$DOMAIN -m $EMAIL --agree-tos --non-interactive

CRT_PATH="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
KEY_PATH="/etc/letsencrypt/live/$DOMAIN/privkey.pem"

if [[ -f "$CRT_PATH" && -f "$KEY_PATH" ]]; then
    echo "[INFO] Symlink chứng chỉ vào iRedMail paths..."
    ln -sf $CRT_PATH /etc/ssl/certs/iRedMail.crt
    ln -sf $KEY_PATH /etc/ssl/private/iRedMail.key
else
    echo "[ERROR] Chứng chỉ Let's Encrypt không tồn tại, kiểm tra lại Certbot."
    exit 1
fi

# 3️⃣ Đọc DKIM public key
if [[ -f "/var/lib/dkim/$DOMAIN.pem" ]]; then
    DKIM_PUB=$(sed -n '/BEGIN PUBLIC KEY/,/END PUBLIC KEY/{/BEGIN PUBLIC KEY/b;/END PUBLIC KEY/b;p}' /var/lib/dkim/$DOMAIN.pem | tr -d '\n')
else
    DKIM_PUB="CHƯA TẠO (sử dụng amavisd -c /etc/amavis/conf.d/50-user showkeys)"
fi

# 4️⃣ Xuất hướng dẫn cấu hình DNS
echo "================================================================="
echo "✅ Cập nhật DNS cho mail server $DOMAIN:"
echo "1. A record:"
echo "   $DOMAIN -> $(curl -s ifconfig.me)"
echo "   mail.$DOMAIN -> $(curl -s ifconfig.me)"
echo "2. MX record:"
echo "   $DOMAIN MX 10 mail.$DOMAIN"
echo "3. SPF record (TXT):"
echo "   v=spf1 mx ~all"
echo "4. DKIM record (TXT):"
echo "   dkim._domainkey.$DOMAIN TXT \"v=DKIM1; p=$DKIM_PUB\""
echo "5. DMARC record (TXT):"
echo "   _dmarc.$DOMAIN TXT \"v=DMARC1; p=none; rua=mailto:$EMAIL\""
echo "6. PTR record:"
echo "   (phải cấu hình tại nhà cung cấp VPS/IP)"
echo "================================================================="

# 5️⃣ Reload Nginx
echo "[INFO] Reload Nginx..."
nginx -t && systemctl reload nginx

echo "[DONE] Hoàn tất cấp chứng chỉ, symlink, xuất DNS record, reload Nginx!"
