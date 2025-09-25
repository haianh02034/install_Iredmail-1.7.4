#!/bin/bash
# Script tự động cấu hình OpenDKIM cho iRedMail 1.7.4
# Chạy trên Ubuntu 22.04

DOMAIN="domain"
SELECTOR="mail"
OPENDKIM_CONF="/etc/opendkim.conf"
KEYS_DIR="/etc/opendkim/keys/$DOMAIN"

echo "=== 1. Cài OpenDKIM và công cụ liên quan ==="
apt update
apt install -y opendkim opendkim-tools

echo "=== 2. Tạo thư mục và quyền cho DKIM ==="
mkdir -p $KEYS_DIR
chown -R opendkim:opendkim /etc/opendkim
chmod go-rwx /etc/opendkim/keys

echo "=== 3. Tạo DKIM key cho domain $DOMAIN ==="
cd $KEYS_DIR
opendkim-genkey -s $SELECTOR -d $DOMAIN
chown opendkim:opendkim $SELECTOR.private
chmod 600 $SELECTOR.private

echo "=== 4. Tạo cấu hình KeyTable, SigningTable, TrustedHosts ==="
cat > /etc/opendkim/key.table <<EOF
$SELECTOR._domainkey.$DOMAIN $DOMAIN:$SELECTOR:$KEYS_DIR/$SELECTOR.private
EOF

cat > /etc/opendkim/signing.table <<EOF
*@${DOMAIN} $SELECTOR._domainkey.$DOMAIN
EOF

cat > /etc/opendkim/trusted.hosts <<EOF
127.0.0.1
::1
$DOMAIN
EOF

echo "=== 5. Cấu hình /etc/opendkim.conf ==="
cat > $OPENDKIM_CONF <<EOF
AutoRestart             Yes
AutoRestartRate         10/1h
UMask                   002
Syslog                  Yes
SyslogSuccess           Yes
LogWhy                  Yes

Canonicalization        relaxed/simple
Mode                    sv
SubDomains              no
ADSPAction              continue
OversignHeaders         From

Socket                  inet:8891@127.0.0.1
PidFile                 /var/run/opendkim/opendkim.pid
UserID                  opendkim:opendkim

KeyTable                /etc/opendkim/key.table
SigningTable            /etc/opendkim/signing.table
ExternalIgnoreList      /etc/opendkim/trusted.hosts
InternalHosts           /etc/opendkim/trusted.hosts
EOF

echo "=== 6. Cấu hình Postfix tích hợp OpenDKIM ==="
postconf -e "milter_default_action = accept"
postconf -e "smtpd_milters = inet:127.0.0.1:8891"
postconf -e "non_smtpd_milters = inet:127.0.0.1:8891"

echo "=== 7. Khởi động và enable dịch vụ ==="
systemctl restart opendkim
systemctl enable opendkim
systemctl restart postfix

echo "=== 8. In DNS record DKIM để thêm vào zone ==="
echo "--- TXT record ---"
cat $SELECTOR.txt
