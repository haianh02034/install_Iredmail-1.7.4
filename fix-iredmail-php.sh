#!/bin/bash
# fix-iredmail-php.sh
# Tự động fix tất cả template iRedMail backend khi PHP-FPM thay đổi cổng/socket

PHP_POOL_CONF="/etc/php/8.1/fpm/pool.d/www.conf"
TEMPLATE_DIR="/etc/nginx/templates"

# 1️⃣ Đọc listen từ PHP-FPM pool
LISTEN_LINE=$(grep -E "^listen\s*=" $PHP_POOL_CONF | awk -F'= ' '{print $2}' | tr -d ' ')
if [[ -z "$LISTEN_LINE" ]]; then
    echo "[ERROR] Không tìm thấy listen trong $PHP_POOL_CONF"
    exit 1
fi

echo "[INFO] PHP-FPM listen: $LISTEN_LINE"

# 2️⃣ Scan tất cả template có fastcgi_pass
TEMPLATES=$(grep -l "fastcgi_pass" $TEMPLATE_DIR/*.tmpl)
if [[ -z "$TEMPLATES" ]]; then
    echo "[WARNING] Không tìm thấy template nào có fastcgi_pass"
else
    for tmpl in $TEMPLATES; do
        echo "[INFO] Backup template: $tmpl -> ${tmpl}.bak"
        cp $tmpl ${tmpl}.bak

        echo "[INFO] Chỉnh fastcgi_pass trong $tmpl"
        if [[ "$LISTEN_LINE" == /* ]]; then
            # Nếu là socket
            sed -i "s|fastcgi_pass .*;|fastcgi_pass unix:$LISTEN_LINE;|g" $tmpl
        else
            # Nếu là IP:PORT
            sed -i "s|fastcgi_pass .*;|fastcgi_pass $LISTEN_LINE;|g" $tmpl
        fi
    done
fi

# 3️⃣ Reload PHP-FPM và Nginx
echo "[INFO] Reload PHP-FPM và Nginx..."
systemctl restart php8.1-fpm
systemctl restart nginx

# 4️⃣ Kiểm tra trạng thái
echo "[INFO] Kiểm tra trạng thái PHP-FPM và Nginx..."
systemctl status php8.1-fpm --no-pager
systemctl status nginx --no-pager

echo "[DONE] Đã cập nhật tất cả template iRedMail để dùng PHP-FPM đúng listen."
echo "Hãy thử truy cập lại các backend: Roundcube, iRedAdmin, SOGo..."
