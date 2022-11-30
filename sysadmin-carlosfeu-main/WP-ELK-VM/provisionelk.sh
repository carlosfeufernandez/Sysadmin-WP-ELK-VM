#!/bin/bash

#Entramos en root
sudo su -
#Actualizar
apt-get update
#Instalamos las dependencias de java
apt-get install -y  default-jre
#Instalamos el servidor nginx
apt-get -y install nginx
#Instalacion clave GPG de repositorio elastic search para ubuntu server
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
#Instalamos el paquete apt-transport-https. Ofrece a nuestro sistema la posibilidad de actualizar los paquetes con conexión SSL.
sudo apt-get install apt-transport-https
#Añadimos repo de elasticsearch y actualizamos
echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-7.x.list
sudo apt update
#Instalacion logstash
apt install logstash
#Configuraración logstash
ARCHIVO1=/etc/logstash/conf.d/02-beats-input.conf
if ! [ -f "$ARCHIVO1" ]; then
    cat << EOF > $ARCHIVO1
    input {
         beats {
            port => 5044
        }
    }
EOF
fi

ARCHIVO2=/etc/logstash/conf.d/10-syslog-filter.conf
if ! [ -f "$ARCHIVO2" ]; then
    cat << EOF > $ARCHIVO2
    filter {
  if [fileset][module] == "system" {
    if [fileset][name] == "auth" {
      grok {
        match => { "message" => ["%{SYSLOGTIMESTAMP:[system][auth][timestamp]} %{SYSLOGHOST:[system][auth][hostname]} sshd(?:\[%{POSINT:[system][auth][pid]}\])?: %{DATA:[system][auth][ssh][event]} %{DATA:[system][auth][ssh][method]} for (invalid user )?%{DATA:[system][auth][user]} from %{IPORHOST:[system][auth][ssh][ip]} port %{NUMBER:[system][auth][ssh][port]} ssh2(: %{GREEDYDATA:[system][auth][ssh][signature]})?",
                  "%{SYSLOGTIMESTAMP:[system][auth][timestamp]} %{SYSLOGHOST:[system][auth][hostname]} sshd(?:\[%{POSINT:[system][auth][pid]}\])?: %{DATA:[system][auth][ssh][event]} user %{DATA:[system][auth][user]} from %{IPORHOST:[system][auth][ssh][ip]}",
                  "%{SYSLOGTIMESTAMP:[system][auth][timestamp]} %{SYSLOGHOST:[system][auth][hostname]} sshd(?:\[%{POSINT:[system][auth][pid]}\])?: Did not receive identification string from %{IPORHOST:[system][auth][ssh][dropped_ip]}",
                  "%{SYSLOGTIMESTAMP:[system][auth][timestamp]} %{SYSLOGHOST:[system][auth][hostname]} sudo(?:\[%{POSINT:[system][auth][pid]}\])?: \s*%{DATA:[system][auth][user]} :( %{DATA:[system][auth][sudo][error]} ;)? TTY=%{DATA:[system][auth][sudo][tty]} ; PWD=%{DATA:[system][auth][sudo][pwd]} ; USER=%{DATA:[system][auth][sudo][user]} ; COMMAND=%{GREEDYDATA:[system][auth][sudo][command]}",
                  "%{SYSLOGTIMESTAMP:[system][auth][timestamp]} %{SYSLOGHOST:[system][auth][hostname]} groupadd(?:\[%{POSINT:[system][auth][pid]}\])?: new group: name=%{DATA:system.auth.groupadd.name}, GID=%{NUMBER:system.auth.groupadd.gid}",
                  "%{SYSLOGTIMESTAMP:[system][auth][timestamp]} %{SYSLOGHOST:[system][auth][hostname]} useradd(?:\[%{POSINT:[system][auth][pid]}\])?: new user: name=%{DATA:[system][auth][user][add][name]}, UID=%{NUMBER:[system][auth][user][add][uid]}, GID=%{NUMBER:[system][auth][user][add][gid]}, home=%{DATA:[system][auth][user][add][home]}, shell=%{DATA:[system][auth][user][add][shell]}$",
                  "%{SYSLOGTIMESTAMP:[system][auth][timestamp]} %{SYSLOGHOST:[system][auth][hostname]} %{DATA:[system][auth][program]}(?:\[%{POSINT:[system][auth][pid]}\])?: %{GREEDYMULTILINE:[system][auth][message]}"] }
        pattern_definitions => {
          "GREEDYMULTILINE"=> "(.|\n)*"
        }
        remove_field => "message"
      }
      date {
        match => [ "[system][auth][timestamp]", "MMM  d HH:mm:ss", "MMM dd HH:mm:ss" ]
      }
      geoip {
        source => "[system][auth][ssh][ip]"
        target => "[system][auth][ssh][geoip]"
      }
    }
    else if [fileset][name] == "syslog" {
      grok {
        match => { "message" => ["%{SYSLOGTIMESTAMP:[system][syslog][timestamp]} %{SYSLOGHOST:[system][syslog][hostname]} %{DATA:[system][syslog][program]}(?:\[%{POSINT:[system][syslog][pid]}\])?: %{GREEDYMULTILINE:[system][syslog][message]}"] }
        pattern_definitions => { "GREEDYMULTILINE" => "(.|\n)*" }
        remove_field => "message"
      }
      date {
        match => [ "[system][syslog][timestamp]", "MMM  d HH:mm:ss", "MMM dd HH:mm:ss" ]
      }
    }
  }
}
EOF
fi
ARCHIVO3=/etc/logstash/conf.d/30-elasticsearch-output.conf
if ! [ -f "$ARCHIVO3" ]; then
    cat << EOF > $ARCHIVO3
    output {
        elasticsearch {
            hosts => ["localhost:9200"]
            manage_template => false
            index => "%{[@metadata][beat]}-%{[@metadata][version]}-%{+YYYY.MM.dd}"
        }
    } 
EOF
fi
#Arrancamos el servicio de logstash
systemctl enable logstash --now
#Instalamos elasticsearch
apt install elasticsearch
#Damos los permisos al usuario elasticsearch para escribir en /var/lib/elasticsearch.
chown -R elasticsearch:elasticsearch /var/lib/elasticsearch
chmod -R 754 /var/lib/elasticsearch
#Arrancamos el servicio de elasticsearch
systemctl enable elasticsearch --now
#Instalamos Kibana
apt install kibana
#Modificamos la configuracion de nginx a puerto 80
rm /etc/nginx/sites-available/default -d
ARCHIVO4=/etc/nginx/sites-available/default
if ! [ -f "$ARCHIVO4" ]; then
    cat << EOF > $ARCHIVO4
    # Managed by installation script - Do not change
    server {
        listen 80;
        server_name kibana.demo.com localhost;
        auth_basic "Restricted Access";
        auth_basic_user_file /etc/nginx/htpasswd.users;
        location / {
            proxy_pass http://localhost:5601;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host \$host;
            proxy_cache_bypass \$http_upgrade;
        }
    }  
EOF
fi

#Creamos carpeta .kibana con password en interior
touch /vagrant/.kibana
printf 'patodegoma' > /vagrant/.kibana
#Generamos el fichero htpasswd.users con usuario y pass encriptados.
echo "kibanaadmin:$(openssl passwd -apr1 -in /vagrant/.kibana)" | sudo tee -a /etc/nginx/htpasswd.users
#Reiniciamos los servicios nginx y kibana
service nginx restart
service kibana restart

# FINAL Script de provisión de la VM2