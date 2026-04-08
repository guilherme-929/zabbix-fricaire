#!/bin/bash

# Lê as variáveis do arquivo .env
. .env


# Defina as variáveis ​​do servidor FTP
HOST="45.182.167.230"
PORT="21"
USER="four"
PASSWORD="Four.2022"

# Defina o diretório local e remoto
DIR_LOCAL="/home/four/$ZBX_SERVER_NAME"
DIR_REMOTO="/zabbix-backup/$ZBX_SERVER_NAME"

# Comando lftp para conectar e enviar a pasta
lftp -e "set ftp:ssl-allow no; open -p $PORT -u $USER,$PASSWORD $HOST; mirror -R $DIR_LOCAL $DIR_REMOTO; bye"


rm -R "/home/four/$ZBX_SERVER_NAME"
rm -r "/root/zabbix/backup"

