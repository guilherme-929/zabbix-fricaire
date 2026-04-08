#!/bin/bash

# Instalando dependencias
apt-get update && apt-get upgrade -y && apt-get install curl wget htop unzip sudo -y

# Instalação do docker

curl -fsSL https://get.docker.com | sh

# Instalação docker compose

curl -L "https://github.com/docker/compose/releases/download/v2.0.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# Permissão na pasta 

chmod +x /usr/local/bin/docker-compose

# Adicionar as mibs no servidor 
apt-get install snmp snmpd -y

wget http://ftp.br.debian.org/debian/pool/non-free/s/snmp-mibs-downloader/snmp-mibs-downloader_1.2_all.deb

apt-get install ./snmp-mibs-downloader_1.2_all.deb -y 

wget http://www.iana.org/assignments/ianaippmmetricsregistry-mib/ianaippmmetricsregistry-mib -O /usr/share/snmp/mibs/iana/IANA-IPPM-METRICS-REGISTRY-MIB

wget http://pastebin.com/raw.php?i=p3QyuXzZ -O /usr/share/snmp/mibs/ietf/SNMPv2-PDU

wget http://pastebin.com/raw.php?i=gG7j8nyk -O /usr/share/snmp/mibs/ietf/IPATM-IPMC-MIB

/etc/init.d/snmpd restart

# Entra na pasta para realizar os comandos
cd zabbix


# Criando a interface do docker

docker network create --ipv6 --subnet 2001:3984:3989::/64 --gateway 2001:3984:3989::1 --subnet 172.16.31.0/24 --gateway 172.16.31.1 app_net

# Criando container mariadb


docker build -t telictec/mariadb . 


# Executando o docker compose 
 
docker-compose up -d 

sleep 1m

# Copiando grafana


# Comando para enviar o arquivo para realizar o particionamento do banco.

mv mysql_part.pl /var/lib/docker/volumes/zabbix-telic_mysql-mariaconfd/_data/

# Comando para subir o firewall

cp nftables.conf /etc/

systemctl enable nftables

cd ../

# Limpando a instalação

rm snmp-mibs-downloader_1.2_all.deb

rm zabbix.sh

echo "finalizou........"

