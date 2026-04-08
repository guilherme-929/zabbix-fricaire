#!/bin/bash

# Lê as variáveis do arquivo .env
. .env

# Agora você pode usar as variáveis no script
echo "ZBX_SERVER_NAME: $ZBX_SERVER_NAME"

# Cria a pasta usando o valor da variável de ambiente
mkdir -p "/home/four/$ZBX_SERVER_NAME"
mkdir -p "/root/zabbix/backup"
# Faz o rsync dos arquivos.
rsync -avz /var/lib/docker/volumes/zabbix_grafana_*  /root/zabbix/backup/

rsync -avz /var/lib/docker/volumes/zabbix_externalscripts /root/zabbix/backup/

rsync -avz /var/lib/docker/volumes/zabbix_alertscripts /root/zabbix/backup/

sleep 2

tar -czvf /root/zabbix/backup/zabbix_grafana_etc.tar.gz /root/zabbix/backup/zabbix_grafana_etc
tar -czvf /root/zabbix/backup/zabbix_grafana_grafana.tar.gz /root/zabbix/backup/zabbix_grafana_grafana
tar -czvf /root/zabbix/backup/zabbix_grafana_data.tar.gz /root/zabbix/backup/zabbix_grafana_data
tar -czvf /root/zabbix/backup/zabbix_externalscripts.tar.gz /root/zabbix/backup/zabbix_externalscripts
tar -czvf /root/zabbix/backup/zabbix_alertscripts.tar.gz /root/zabbix/backup/zabbix_alertscripts
# Copia os hots do Zabbix
./hosts.py

mv zabbix_hosts.csv /home/four/$ZBX_SERVER_NAME

# Move para a pasta que vai ser enviada para o servidor.
mv /root/zabbix/backup/*.tar.gz /home/four/$ZBX_SERVER_NAME

docker exec -i mariadb bash -c "cd /var/lib/mysql && mysqldump -u root -p'v6wJVXKbBTKs569a' zabbix > zabbix.sql"

mv /var/lib/docker/volumes/zabbix_mariadb/_data/zabbix.sql /root/zabbix/backup/

gzip -9 /root/zabbix/backup/zabbix.sql 

mv /root/zabbix/backup/zabbix.sql.gz  /home/four/$ZBX_SERVER_NAME

