#!/bin/bash

set -e

### Durcissement d'Apache2 ###

# Suppression des modules inutiles
sudo a2dismod autoindex status userdir cgi || true

# Masquage des informations de version
sudo sed -i 's/^ServerTokens .*/ServerTokens Prod/' /etc/apache2/conf-available/security.conf
sudo sed -i 's/^ServerSignature .*/ServerSignature Off/' /etc/apache2/conf-available/security.conf

# Protection contre Clickjacking
sudo bash -c 'echo "Header always append X-Frame-Options SAMEORIGIN" >> /etc/apache2/conf-available/security.conf'

# Protection contre le MIME sniffing
sudo bash -c 'echo "Header set X-Content-Type-Options: nosniff" >> /etc/apache2/conf-available/security.conf'

# Activer les nouvelles protections
sudo a2enconf security || true
sudo systemctl restart apache2

### Durcissement de la VM (Debian-based) ###

# Désactiver root login SSH
sudo sed -i 's/^PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config

# Désactiver l'accès par mot de passe SSH
#sudo sed -i 's/^#PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config

# Activer UFW avec politique restrictive
sudo apt-get install -y ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow https
sudo ufw --force enable

# Supprimer les paquets inutiles et faire le ménage
sudo apt autoremove --purge -y
sudo apt clean

# Appliquer les mises à jour critiques
sudo apt update && sudo apt upgrade -y

# Vérification finale
echo "Durcissement terminé. Vérifiez les journaux pour toute anomalie."
