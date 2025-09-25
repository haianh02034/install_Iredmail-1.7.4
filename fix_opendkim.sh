#!/bin/bash
set -e

DOMAIN="domain"
SELECTOR="mail"
KEY_DIR="/etc/opendkim/keys/$DOMAIN"
CONF_FILE="/etc/opendkim.conf"
KEY_TABLE="/etc/opendkim/key.table"
SIGNING_TABLE="/etc/opendkim/signing.table"
TRUSTED="/etc/opendkim/trusted.hosts"

echo "=== 1. Backup cấu hình cũ ==="
mkdir -p /root/opendkim_backup
cp -a $CONF_FILE /root/opendkim_backup/opendkim.conf.bak.$(date +%F-%T) || true
cp -a $KEY_TABLE /root/opendkim_backup/key.table.bak.$(date +%F-%T) || true
cp -a $SIGNING_TABLE /root/opendkim_backup/signing.table.bak.$(date +%F-%T) || true

echo "=== 2. Ghi lại file cấu hình opendkim.conf ==="
cat > $CONF_FILE <<EOF
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

Socket                  inet:8891@127.0.0.1
PidFile                 /var/run/opendkim/opendkim.pid
UserID                  opendkim:opendkim

KeyTable                /etc/opendkim/key.table
SigningTable            /etc/opendkim/signing.table
ExternalIgnoreList      /etc/opendkim/trusted.hosts
InternalHosts           /etc/opendkim/trusted.hosts
EOF

echo "=== 3. Ghi lại file key.table ==="
cat > $KEY_TABLE <<EOF
$SELECTOR._domainkey.$DOMAIN $DOMAIN:$SELECTOR:$KEY_DIR/$SELECTOR.private
EOF

echo "=== 4. Ghi lại file signing.table ==="
cat > $SIGNING_TABLE <<EOF
*@${DOMAIN} $SELECTOR._domainkey.$DOMAIN
EOF

echo "=== 5. Ghi lại file trusted.hosts ==="
cat > $TRUSTED <<EOF
127.0.0.1
::1
localhost
$DOMAIN
mail.$DOMAIN
EOF

echo "=== 6. Phân quyền cho key ==="
chown -R opendkim:opendkim /etc/opendkim
chmod 700 /etc/opendkim/keys
chmod 600 $KEY_DIR/$SELECTOR.private

echo "=== 7. Kiểm tra cấu hình ==="
opendkim -n -x $CONF_FILE

echo "=== 8. Restart dịch vụ ==="
systemctl restart opendkim
systemctl enable opendkim
systemctl status opendkim --no-pager

echo "=== 9. Gợi ý DNS DKIM record ==="
PUB_KEY=$(grep -v "PRIVATE" $KEY_DIR/$SELECTOR.txt | tr -d '\n' | sed 's/.*p=//;s/".*//')
echo
echo "Thêm vào DNS TXT record:"
echo "$SELECTOR._domainkey.$DOMAIN IN TXT ( \"v=DKIM1; k=rsa; p=$PUB_KEY\" )"
echo
echo "Sau đó kiểm tra bằng:"
echo "opendkim-testkey -d $DOMAIN -s $SELECTOR -vvv"
