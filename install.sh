#!/bin/bash

# Check if the script is being run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Update package lists
sudo apt update

# Install software-properties-common
sudo apt install -y software-properties-common

# Add repository for PHP 7.4 and 8.2
sudo add-apt-repository -y ppa:ondrej/php
sudo apt update

# Install Apache2 and necessary modules
sudo apt install -y apache2 libapache2-mod-fcgid

# Enable Apache2 fcgid module
sudo a2enmod proxy_fcgi setenvif

# Enable Apache to start at boot
sudo systemctl enable apache2

# Generate a random password for MySQL root
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32)
echo "MySQL root password: ${MYSQL_ROOT_PASSWORD}"

# Automatically set the MySQL root password
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password $MYSQL_ROOT_PASSWORD"
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD"

# Install MariaDB (MySQL)
sudo apt install -y mariadb-server mariadb-client

# Install PHP 7.4 and its commonly used modules
sudo apt install -y php7.4 php7.4-fpm php7.4-mysql php7.4-all-dev
sudo a2enconf php7.4-fpm

# Install PHP 8.2 and its commonly used modules
sudo apt install -y php8.2 php8.2-fpm php8.2-mysql php8.2-all-dev
sudo a2enconf php8.2-fpm

# Pre-configure phpMyAdmin to use Apache2 and dbconfig-common
echo 'phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2' | sudo debconf-set-selections
echo 'phpmyadmin phpmyadmin/dbconfig-install boolean true' | sudo debconf-set-selections
echo 'phpmyadmin phpmyadmin/mysql/admin-pass password $MYSQL_ROOT_PASSWORD' | sudo debconf-set-selections
echo 'phpmyadmin phpmyadmin/mysql/app-pass password $MYSQL_ROOT_PASSWORD' | sudo debconf-set-selections
echo 'phpmyadmin phpmyadmin/app-password-confirm password $MYSQL_ROOT_PASSWORD' | sudo debconf-set-selections

# Install phpMyAdmin and enable it
sudo apt install -y phpmyadmin
sudo ln -s /etc/phpmyadmin/apache.conf /etc/apache2/conf-available/phpmyadmin.conf
sudo a2enconf phpmyadmin
sudo systemctl reload apache2

# Create the necessary directories
sudo mkdir -p /var/www/html/lazy/web/admin
sudo mkdir -p /var/www/html/lazy/default

# Create a PHP file that calls phpinfo() in the /var/www/html/lazy/web/admin directory
echo "<?php phpinfo(); ?>" | sudo tee /var/www/html/lazy/web/admin/index.php

# Create a PHP file that calls phpinfo() in the /var/www/html/lazy/default directory
echo "<?php phpinfo(); ?>" | sudo tee /var/www/html/lazy/default/index.php

# Make Apache listen to port 3000
echo "Listen 3000" | sudo tee /etc/apache2/ports.conf

# Create a new virtual host for your default domain on port 80
echo "<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html/lazy/default
    <FilesMatch \.php$>
        SetHandler "proxy:unix:/run/php/php7.4-fpm.sock|fcgi://localhost/"
    </FilesMatch>
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>" | sudo tee /etc/apache2/sites-available/default.conf

# Enable the new virtual host
sudo a2ensite default
sudo systemctl reload apache2

# Create a new virtual host for your web admin panel on port 3000
echo "<VirtualHost *:3000>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html/lazy/web/admin
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>" | sudo tee /etc/apache2/sites-available/webadmin.conf

# Enable the new virtual host
sudo a2ensite webadmin
sudo systemctl reload apache2

# Restart Apache to load the PHP module
sudo systemctl restart apache2

echo "LAMP stack with PHP-FPM 7.4 and 8.2, phpMyAdmin, all available PHP extensions, a custom Apache root directory, and a web admin panel listening on port 3000 installed successfully."
