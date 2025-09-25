# install_Iredmail-1.7.4 - << khuyến nghị sử dụng ubuntu 22.04 >>  


1) Bản ghi DNS cần thêm / sửa (điền vào giao diện quản lý DNS của bạn)

1. A record

Tên: mail

Loại: A

Giá trị: 12.23.34.56

TTL: (mặc định)

Nếu bạn đã có @ (root) trỏ về 12.23.34.56, vẫn nên có mail riêng để SSL/hostname mail.yourdomain hoạt động ổn định.

2. MX record

Tên: @ (hoặc để trống tuỳ panel)

Loại: MX

Giá trị: mail.domain

Độ ưu tiên: 10

3. SPF (TXT)

Tên: @

Loại: TXT

Giá trị (1 dòng):

v=spf1 ip4:12.23.34.56 -all


Nếu bạn sẽ gửi mail qua thêm dịch vụ bên thứ ba (Google Workspace, SendGrid...), thêm include:... tương ứng. Dấu -all là strict (từ chối); lúc đầu bạn có thể dùng ~all (softfail) để giám sát.

4. DKIM (TXT) — placeholder, cần tạo key trên server

Bạn phải tạo key trên server (ví dụ selector s1 hoặc s202509). Sau khi tạo file public key, thêm TXT record dạng:

Tên: s1._domainkey (nếu selector là s1)

Loại: TXT

Giá trị (ví dụ):

v=DKIM1; k=rsa; p=MIIBIjANBgkq...rest-of-public-key...


Không paste private key lên DNS — chỉ public key (chuỗi sau p=). Mình sẽ hướng dẫn cách tạo key ngay bên dưới.

5. DMARC (TXT)

Tên: _dmarc

Loại: TXT

Giá trị (bắt đầu giám sát, gửi báo cáo):

v=DMARC1; p=quarantine; rua=mailto:dmarc@domain; ruf=mailto:dmarc@domain; pct=100; fo=1


Bạn cần tạo mailbox dmarc@domain hoặc forward cho email nhận báo cáo DMARC.

2) Cài đặt DKIM (tóm tắt các lệnh trên server Ubuntu)

Giả sử selector bạn chọn là s1 và domain domain.

cài opendkim:

sudo apt update
sudo apt install opendkim opendkim-tools -y


tạo thư mục và key:

sudo mkdir -p /etc/opendkim/keys/domain
cd /etc/opendkim/keys/domain
sudo opendkim-genkey -s s1 -d domain
sudo chown opendkim:opendkim s1.private


file s1.txt chứa public key (copy phần p= từ file đó vào DNS TXT cho s1._domainkey.domain).

cấu hình opendkim (thêm domain/selector, gán milter cho postfix) — mình có thể cung cấp config mẫu nếu cần.

3) PTR (reverse DNS)

Quan trọng: Reverse DNS (PTR) phải trỏ IP 12.23.34.56 → mail.domain. PTR do nhà cung cấp IP (hosting/VPS/cloud) cấu hình — bạn phải mở ticket với họ hoặc thao tác trong control panel provider. Nếu PTR không khớp, nhiều mail provider (Gmail, Outlook) dễ đánh giảm điểm hoặc block.

4) Kiểm tra sau khi cấu hình

Sau khi cập nhật DNS (chờ propagation 5–60 phút, có khi vài giờ):

Kiểm tra MX/SPF/DKIM/DMARC:

dig MX domain +short

dig TXT domain +short (xem SPF)

dig TXT s1._domainkey.domain +short (xem DKIM public)

dig TXT _dmarc.domain +short (xem DMARC)

Gửi mail test tới Gmail và kiểm tra header (View original) — kiểm tra spf=pass, dkim=pass, dmarc=pass (hoặc báo lỗi).

Công cụ online: MXToolbox (MX Lookup / DKIM Lookup / SPF Lookup / Blacklist check).

5) Cấu hình Postfix/Dovecot/SSL cơ bản (tóm tắt)

Postfix main.cf:

myhostname = mail.domain

mydestination không chứa domain nếu dùng virtual domains

TLS cert: /etc/letsencrypt/live/mail.domain/fullchain.pem và privkey.pem

tích hợp OpenDKIM milter (smtpd_milters = inet:localhost:8891)

Dovecot: bật SSL, trỏ cert/key tới letsencrypt, hỗ trợ IMAPS (993) và submission STARTTLS (587).

Certbot (Let's Encrypt) cấp cert:

sudo apt install certbot python3-certbot-nginx
sudo certbot certonly --nginx -d mail.domain


(hoặc dùng webroot)

6) Một số lưu ý vận hành & an toàn

Khi go-live: bắt đầu với DMARC p=quarantine hoặc p=none để giám sát vài ngày; chỉ p=reject khi đảm bảo SPF/DKIM ổn định.

Giới hạn tần suất gửi (rate-limit) để tránh bị block.

Bật fail2ban cho dịch vụ SMTP/IMAP.

Lưu private DKIM keys an toàn, backup.

7) Nếu bạn muốn — mình sẽ làm tiếp (một trong các lựa chọn, mình sẽ thực hiện ngay trong tin nhắn này)

A. Soạn nội dung chính xác để bạn copy/paste vào form “Thêm Record” trên panel DNS (mình sẽ liệt kê dòng theo thứ tự).
B. Viết cấu hình OpenDKIM + Postfix (file mẫu) sẵn sàng để dán lên server.
C. Hướng dẫn kiểm tra step-by-step (dig, openssl, gửi test + giải thích header mail).
