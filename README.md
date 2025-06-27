# 🚀 Script d’installation automatisée de GLPI 10 sur Debian 12

Ce script shell installe **GLPI (dernière version)** avec toutes les bonnes pratiques d’IT-Connect :  
Apache sécurisé (SSL + HSTS), PHP-FPM 8.2 durci, MariaDB configurée, arborescence optimisée.

---

## 🧩 Étapes automatisées

1. **Mise à jour du système**  
   + Installation des paquets requis : Apache2, MariaDB, PHP 8.2, extensions GLPI, outils utilitaires.

2. **Configuration de la base de données**  
   + Sécurisation de MariaDB  
   + Création de la base `glpidb` et de l’utilisateur `glpiuser`  
   + Vérification automatique de la version de MariaDB recommandée par GLPI

3. **Téléchargement de GLPI**  
   + Récupération dynamique de la dernière version disponible sur GitHub  
   + Création des répertoires conformes (`/etc/glpi`, `/var/lib/glpi`, `/var/log/glpi`)  
   + Nettoyage des anciennes installations résiduelles  
   + Mise en place de `downstream.php` et `local_define.php`  

4. **Configuration Apache2**  
   + Création d’un VirtualHost `glpi.local` avec HTTPS (certificat autosigné)  
   + Activation des modules nécessaires (SSL, rewrite, headers, etc.)  
   + Désactivation/suppression des vhosts inutiles  
   + Application des règles de sécurité HTTP

5. **Durcissement de PHP (via PHP-FPM)**  
   + Activation de PHP-FPM pour Apache2  
   + Sécurisation des cookies (`httponly`, `secure`)  
   + Redémarrage des services Apache et PHP

---

## 🔐 Sécurité appliquée

- Certificat **autosigné** avec OpenSSL (valide 365 jours)
- En-tête **Strict-Transport-Security (HSTS)** activée
- **Sécurisation des cookies PHP** : `session.cookie_httponly = on` et `session.cookie_secure = on`
- Suppression des vhosts Apache par défaut

---

## 📁 Arborescence recommandée

| Répertoire              | Rôle                       |
|-------------------------|----------------------------|
| `/var/www/glpi`         | Fichiers web applicatifs   |
| `/etc/glpi`             | Fichiers de configuration  |
| `/var/lib/glpi`         | Données (fichiers GLPI)    |
| `/var/log/glpi`         | Logs de l’application      |

---

## 📎 Pré-requis

- Système : **Debian 12**
- DNS local : `glpi.local` pointant vers le serveur

---

## 🧪 Accès post-installation

Accédez à l’interface :  
➡️ [https://glpi.local](https://glpi.local)  

Identifiants initiaux :  
- **glpi / glpi**  
- **tech / tech**  
- **normal / normal**

---

## 🛠️ Sources officielles

- [Documentation GLPI officielle](https://glpi-install.readthedocs.io/fr/develop/)
- [Tutoriel IT-Connect (Debian 12)](https://www.it-connect.fr/installation-pas-a-pas-de-glpi-10-sur-debian-12/)

# 🔐 Script de durcissement Apache et de la VM (Debian)

Ce script automatise plusieurs tâches de sécurisation d’un environnement GLPI hébergé sous Apache2 sur une VM Debian. Il suit les bonnes pratiques générales de sécurité, et certaines recommandations de l’ANSSI.

## 🎯 Objectifs

- Renforcer la configuration d’Apache2 (en-têtes HTTP, désactivation des modules inutiles, etc.)
- Sécuriser le système hôte (mise à jour, verrouillage du SSH, règles de base)
- Appliquer un minimum de bonne hygiène de durcissement système

## 🧩 Fonctionnalités du script

### 🔐 Apache

- Suppression des bannières et informations de version
- Activation de headers HTTP de sécurité :
  - `X-Content-Type-Options: nosniff`
  - `X-Frame-Options: DENY`
  - `X-XSS-Protection: 1; mode=block`
  - `Referrer-Policy: strict-origin-when-cross-origin`
- Désactivation de modules non nécessaires (`status`, `autoindex`, `cgi`, etc.)
- Configuration stricte des répertoires (`Options -Indexes`)

### 🛡️ Système

- Suppression des paquets inutiles (ex. `telnet`)
- Activation automatique des mises à jour de sécurité
- Verrouillage SSH (désactivation root, SSHv2 only, fail2ban si activé)
- Création d’un utilisateur d’administration si besoin
- Application de permissions plus restrictives sur certains fichiers de conf

## 📝 Remarques

- Ce script est conçu pour être lancé une fois l’installation de GLPI terminée.
- Il est **fortement conseillé** de le tester dans un environnement de test avant une mise en production.
- Il peut être intégré dans une politique de durcissement plus globale (cf. [guide ANSSI](https://www.ssi.gouv.fr/guide/)).

## 🚀 Exécution

```bash
sudo bash harden_apache_vm.sh

