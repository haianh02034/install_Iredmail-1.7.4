<?php
/**
 * Auto IMAP login checker for iRedMail users
 */
// dbPass: Thay bằng mật khẩu thật của bạn file iRedmail.tips
$dbHost = '127.0.0.1';
$dbUser = 'vmail';
$dbPass = '**********************';
$dbName = 'vmail';
$dbPort = 3306;

try {
    $pdo = new PDO("mysql:host=$dbHost;dbname=$dbName;port=$dbPort;charset=utf8", $dbUser, $dbPass);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

    $stmt = $pdo->query("SELECT username, password FROM mailbox");
    $users = $stmt->fetchAll(PDO::FETCH_ASSOC);

    echo "Found " . count($users) . " users\n";

    foreach ($users as $user) {
        $username = $user['username'];
        $password = str_replace('$', '\\$', $user['password']); // escape $

        $success = false;

        // Thử 993 SSL
        $imapSSL = "{" . "ssl://domain" . ":993/imap/ssl/novalidate-cert}";
        $imap = @imap_open($imapSSL, $username, $password);
        if ($imap) {
            $success = true;
            imap_close($imap);
            echo "[OK] $username login successful via 993 SSL\n";
        } else {
            // Thử 143 STARTTLS
            $imapSTARTTLS = "{" . "domain" . ":143/imap/notls}";
            $imap = @imap_open($imapSTARTTLS, $username, $password);
            if ($imap) {
                $success = true;
                imap_close($imap);
                echo "[OK] $username login successful via 143 STARTTLS\n";
            }
        }

        if (!$success) {
            echo "[FAIL] $username login failed: " . imap_last_error() . "\n";
        }
    }

} catch (PDOException $e) {
    echo "DB Error: " . $e->getMessage() . "\n";
    exit(1);
}
