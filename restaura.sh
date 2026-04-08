#!/bin/bash
# Copyright Guilherme Santos 2022 #
# COMANDO PARA ENVIAR O BANCO PARA O VOLUME
#mv /root/backup/backup-zabbix/zabbix.sql /var/lib/docker/volumes/mariadb/_data/


# COMANDO PARA REMOVER O BANCO
docker exec -i mariadb bash -c "cd /var/lib/mysql && mysql -u root -psenha zabbix < zabbix.db"

# COMANDO PARA LIMPAR O BANCO DO VOLUME
#sleep 10
#rm /var/lib/docker/volumes/mariadb/_data/zabbix.sql

