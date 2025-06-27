#!/bin/bash
#
# harden_extra.sh – Compléments ANSSI pour un serveur GLPI Debian 12
# (à exécuter après le script d’installation principal)
#
#  • TLS & ciphers stricts
#  • fail2ban (SSH + Apache)
#  • sysctl réseau / noyau
#  • auditd : suivi des fichiers sensibles
#  • durcissement PHP (expose_php, disable_functions, open_basedir)
#  • logrotate dédié pour GLPI
#---------------------------------------------------------------

set -e

### 1. TLS strict (SSLParams) ##############################
echo "[TLS] Renforcement ciphers/Protocoles"
cat >/etc/apache2/conf-available/ssl-params.conf <<'EOF'
# ANSSI Réf. RGS v2.0 + guide TLS
SSLProtocol             -ALL +TLSv1.2 +TLSv1.3
SSLCipherSuite          TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_128_GCM_SHA256
SSLHonorCipherOrder     on
SSLCompression          off
SSLSessionTickets       off
SSLUseStapling          on
SSLOpenSSLConfCmd       Curves secp384r1
Header always set X-Content-Type-Options "nosniff"
Header always set X-XSS-Protection "1; mode=block"
Header always set Referrer-Policy "strict-origin-when-cross-origin"
EOF
a2enconf ssl-params

### 2. fail2ban ###########################################
echo "[fail2ban] Installation et jails SSH + Apache"
apt install -y fail2ban
cat >/etc/fail2ban/jail.d/glpi.conf <<'EOF'
[sshd]
enabled  = true
port     = ssh
filter   = sshd
logpath  = /var/log/auth.log
maxretry = 5

[apache-glpi]
enabled   = true
port      = https
filter    = apache-auth
logpath   = /var/log/apache2/glpi_error.log
maxretry  = 5
EOF
systemctl enable --now fail2ban

### 3. sysctl (réseau/noyau) ###############################
echo "[sysctl] Durcissement réseau"
cat >/etc/sysctl.d/99-hardening.conf <<'EOF'
# ANSSI – désactivation routage et redirects
net.ipv4.ip_forward = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.rp_filter = 1
# randomisation ASLR
kernel.randomize_va_space = 2
EOF
sysctl --system

### 4. auditd ##############################################
echo "[auditd] Installation et règles GLPI"
apt install -y auditd
cat >/etc/audit/rules.d/glpi.rules <<EOF
-w /var/www/glpi -p wa -k glpi_web
-w /etc/glpi        -p wa -k glpi_conf
-w /var/lib/glpi    -p wa -k glpi_data
-w /var/log/glpi    -p wa -k glpi_logs
EOF
augenrules --load
systemctl enable --now auditd

### 5. PHP hardening ######################################
echo "[PHP] expose_php off, cookies sécurisés, disable_functions"
PHP_INI="/etc/php/8.2/fpm/php.ini"
sed -i 's/^expose_php.*/expose_php = Off/'         "$PHP_INI"
sed -i 's/^;*disable_functions.*/disable_functions = exec,passthru,shell_exec,system,proc_open,popen,pcntl_exec/' "$PHP_INI"
sed -i 's|^;*open_basedir.*|open_basedir = /var/www/glpi:/tmp|' "$PHP_INI"
sed -i 's/^;*session.cookie_httponly.*/session.cookie_httponly = on/' "$PHP_INI"
sed -i 's/^;*session.cookie_secure.*/session.cookie_secure = on/'   "$PHP_INI"
systemctl restart php8.2-fpm

### 6. Logrotate dédié GLPI ################################
echo "[logrotate] Règle spécifique GLPI"
cat >/etc/logrotate.d/glpi <<'EOF'
/var/log/apache2/glpi_access.log /var/log/apache2/glpi_error.log /var/log/glpi/*.log {
    daily
    rotate 14
    compress
    missingok
    notifempty
    create 0640 www-data adm
    sharedscripts
    postrotate
        systemctl reload apache2 > /dev/null 2>&1 || true
    endscript
}
EOF

### 7. Redémarrage Apache ##################################
systemctl restart apache2

echo "Durcissement complémentaire ANSSI appliqué ✔"
