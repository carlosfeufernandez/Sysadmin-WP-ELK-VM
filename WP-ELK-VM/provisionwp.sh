#!/bin/bash

#Instalación y configuración de nginx
apt update -y
apt install nginx -y
ufw allow 'Nginx HTTP'
systemctl start nginx

#Borramos el archivo default de /etc/nginx/sites-available/default
FILESITE=/etc/nginx/sites-available/default
if  [ -f "$FILESITE" ]; then
    rm /etc/nginx/sites-available/default
    unlink /etc/nginx/sites-enabled/default
fi

ARCHIVO=/etc/nginx/sites-available/wordpress
if ! [ -f "$ARCHIVO" ]; then
	cat << EOF > $ARCHIVO
    # Managed by installation script - Do not change
        server {
            listen 80;
            root /var/www/wordpress;
            index index.php index.html index.htm index.nginx-debian.html;
            server_name localhost;
            location / {
            try_files \$uri \$uri/ =404;
        }
            location ~ \.php\$ {
            include snippets/fastcgi-php.conf;
            fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;
        }
            location ~ /\.ht {
            deny all;
        }
    }
EOF
fi

#Creamos el link simbólico
LINK=/etc/nginx/sites-enabled/wordpress
if ! [ -f "$LINK" ]; then
    ln -s /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/
fi

#Reiniciamos el servicio de nginx
systemctl restart nginx

#Instalamos MariaDB
apt install mariadb-server -y

#Arrancamos el servicio de MariaDB
systemctl start mariadb.service

#Segurizamos MariaDB
mysql -sfu root <<EOS
-- set root password
UPDATE mysql.user SET Password=PASSWORD('root123') WHERE User='root';
-- delete anonymous users
DELETE FROM mysql.user WHERE User='';
-- delete remote root capabilities
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
-- drop database 'test'
DROP DATABASE IF EXISTS test;
-- also make sure there are lingering permissions to it
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
-- make changes immediately
FLUSH PRIVILEGES;
CREATE DATABASE wordpress DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;
GRANT ALL ON wordpress.* TO 'root'@'localhost' IDENTIFIED BY 'root123';
FLUSH PRIVILEGES;
EOS

#Instalación y configuración de WORDPRESS
apt install php-fpm php-mysql expect php-curl php-gd php-intl php-mbstring php-soap php-xml php-xmlrpc php-zip -y
sudo systemctl restart php7.4-fpm

cd /tmp
curl -LO https://wordpress.org/latest.tar.gz
tar xzvf latest.tar.gz

cp /tmp/wordpress/wp-config-sample.php /tmp/wordpress/wp-config.php
cp -a /tmp/wordpress/. /var/www/wordpress

sudo chown -R www-data:www-data /var/www/wordpress

cat << EOF > /var/www/wordpress/wp-config.php
<?php
define( 'DB_NAME', 'wordpress' );
define( 'DB_USER', 'root' );
define( 'DB_PASSWORD', 'root123' );
define( 'DB_HOST', 'localhost' );
define( 'DB_CHARSET', 'utf8' );
define( 'DB_COLLATE', '' );
define( 'AUTH_KEY',         'put your unique phrase here' );
define( 'SECURE_AUTH_KEY',  'put your unique phrase here' );
define( 'LOGGED_IN_KEY',    'put your unique phrase here' );
define( 'NONCE_KEY',        'put your unique phrase here' );
define( 'AUTH_SALT',        'put your unique phrase here' );
define( 'SECURE_AUTH_SALT', 'put your unique phrase here' );
define( 'LOGGED_IN_SALT',   'put your unique phrase here' );
define( 'NONCE_SALT',       'put your unique phrase here' );
\$table_prefix = 'wp_';
if ( ! defined( 'ABSPATH' ) ) {
	define( 'ABSPATH', __DIR__ . '/' );
}
require_once ABSPATH . 'wp-settings.php';
EOF

#Descargando e instalando Filebeat, importando la Key de su repositorio y a continuación se añade el repositorio:
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -
echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | tee -a /etc/apt/sources.list.d/elastic-7.x.list
apt-get update
apt-get install -y filebeat
filebeat modules enable system
filebeat modules enable nginx

#Configurando Filebeat:
cd /etc/filebeat
cp filebeat.yml filebeat_nuevo.yml
echo -e "    - /var/log/nginx/*.log\n    - /var/log/mysql/*.log    - /var/log/*.log" > mypaths
tee mycommands.sed >/dev/null 2>&1 <<END
/type: filestream/s/filestream/log/
s/^..enabled: false/  enabled: true/
/^..paths:/r mypaths
s/^output.elasticsearch:/#output.elasticsearch:/
/#output.logstash:/s/#//
s!^..#hosts: \["localhost:5044"\]!  hosts: \["192.168.2.2:5044"\]!
END
sed -f mycommands.sed filebeat_nuevo.yml > filebeat.yml
systemctl enable filebeat --now

#Fin del primer script de provisión 