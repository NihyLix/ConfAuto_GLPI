#!/bin/bash

set -e

### Étape 1 : Mise à jour et installation des paquets nécessaires ###

sudo apt update && sudo apt upgrade -y

sudo apt install -y apache2 mariadb-server php php-xml php-common php-json php-mysql php-mbstring php-curl \
    php-gd php-intl php-zip php-bz2 php-imap php-apcu php-ldap wget tar unzip curl openssl jq

### Étape 2 : Préparation de la base de données MariaDB pour GLPI ###

# Vérification de la version recommandée de MariaDB pour la version GLPI actuelle
LATEST_VERSION=$(curl -s https://api.github.com/repos/glpi-project/glpi/releases/latest | jq -r '.tag_name')
REQUIRED_MARIADB_VERSION="10.6"

INSTALLED_MARIADB_VERSION=$(mariadb --version | grep -oP 'Distrib \K[0-9]+\.[0-9]+')

if [[ $(echo -e "$INSTALLED_MARIADB_VERSION\n$REQUIRED_MARIADB_VERSION" | sort -V | head -n1) != "$REQUIRED_MARIADB_VERSION" ]]; then
  echo "[!] Version de MariaDB trop ancienne ($INSTALLED_MARIADB_VERSION), requise: >= $REQUIRED_MARIADB_VERSION"
  exit 1
else
  echo "[+] Version MariaDB OK ($INSTALLED_MARIADB_VERSION)"
fi

echo "[+] Sécurisation de MariaDB (mot de passe root vide, à personnaliser si besoin)"
sudo mariadb <<EOF
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF

DB_NAME="glpidb"
DB_USER="glpiuser"
DB_PASSWORD="glpipassword"

echo "[+] Création de la base de données GLPI et de l'utilisateur associé"
sudo mariadb <<EOF
CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

### Étape 3 : Préparation des dossiers GLPI et téléchargement ###

cd /tmp
FILE_NAME="glpi-${LATEST_VERSION#v}.tgz"

wget "https://github.com/glpi-project/glpi/releases/download/${LATEST_VERSION}/${FILE_NAME}"
sudo rm -rf /var/www/glpi /etc/glpi /var/lib/glpi /var/log/glpi
sudo tar -xzf ${FILE_NAME} -C /var/www/
sudo chown -R www-data:www-data /var/www/glpi/

sudo mkdir -p /etc/glpi /var/lib/glpi /var/log/glpi

sudo mv /var/www/glpi/config /etc/glpi
sudo mv /var/www/glpi/files /var/lib/glpi

sudo chown -R www-data:www-data /etc/glpi /var/lib/glpi /var/log/glpi

cat <<EOF | sudo tee /var/www/glpi/inc/downstream.php
<?php
define('GLPI_CONFIG_DIR', '/etc/glpi/');
if (file_exists(GLPI_CONFIG_DIR . '/local_define.php')) {
    require_once GLPI_CONFIG_DIR . '/local_define.php';
}
EOF

cat <<EOF | sudo tee /etc/glpi/local_define.php
<?php
define('GLPI_VAR_DIR', '/var/lib/glpi/files');
define('GLPI_LOG_DIR', '/var/log/glpi');
EOF

rm -f /tmp/${FILE_NAME}

### Étape 4 : Configuration Apache ###

VHOST_FILE="/etc/apache2/sites-available/glpi-${LATEST_VERSION#v}.conf"

sudo a2dissite 000-default.conf || true
sudo find /etc/apache2/sites-available -type f ! -name "glpi-${LATEST_VERSION#v}.conf" -delete

sudo a2enmod ssl rewrite headers

sudo mkdir -p /etc/ssl/glpi.local
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/glpi.local/privkey.pem \
    -out /etc/ssl/glpi.local/cert.pem \
    -subj "/C=FR/ST=France/L=Paris/O=GLPI/OU=IT/CN=glpi.local"

cat <<EOF | sudo tee ${VHOST_FILE}
<VirtualHost *:443>
    ServerName glpi.local
    DocumentRoot /var/www/glpi/public

    SSLEngine on
    SSLCertificateFile /etc/ssl/glpi.local/cert.pem
    SSLCertificateKeyFile /etc/ssl/glpi.local/privkey.pem

    Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"

    <Directory /var/www/glpi/public>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
        RewriteEngine On

        # Redirect all requests to GLPI router, unless file exists.
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteRule ^(.*)$ index.php [QSA,L]

    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/glpi_error.log
    CustomLog \${APACHE_LOG_DIR}/glpi_access.log combined
</VirtualHost>
EOF

sudo a2ensite "glpi-${LATEST_VERSION#v}.conf"

### Étape 5 : Configuration PHP avec FPM ###

PHP_VERSION="8.2"

sudo apt install -y php${PHP_VERSION}-fpm
sudo a2enmod proxy_fcgi setenvif
sudo a2enconf php${PHP_VERSION}-fpm || true

PHP_INI="/etc/php/${PHP_VERSION}/fpm/php.ini"
sudo sed -i "s/^;\?session.cookie_httponly.*/session.cookie_httponly = on/" $PHP_INI
sudo sed -i "s/^;\?session.cookie_secure.*/session.cookie_secure = on/" $PHP_INI

cat <<EOF | sudo tee -a ${VHOST_FILE}
<FilesMatch \.php\$>
    SetHandler "proxy:unix:/run/php/php${PHP_VERSION}-fpm.sock|fcgi://localhost/"
</FilesMatch>
EOF

sudo systemctl restart php${PHP_VERSION}-fpm.service
sudo systemctl restart apache2
