# INSTALAÇÃO DO NOVO ZABBIX

Para iniciar a instalação do Zabbix em docker tem algumas instruções que devem ser seguida. 

Acesso ao Grafana 

Usuário: admin

Senha: password

# 1 Para iniciar a instalação do Zabbix e Grafana altere o compose com as seguintes informações.
1.1 Altere a senha do banco de dados

1.2 mude o ip 192.168.3.43 para o ip da vm no container do Grafana

# 2 Faça o git clone do repositorio do cliente dentro do /root do servidor e altere o nome da pasta para ZABBIX-TELIC.

# 3 Copie o arquivo zabbix.sh para o root e de a permissão ao arquivo e execute.

# Este script vai instalar o docker e também o docker-compose, depois disso vai ser criado a interface de rede do docker. Depois deste passo ele vai criar duas imagens um do mariadb e do webhook, logo em seguida ele vai startar os containers. O passo seguinte é remover o grafana para copiar as pastas do grafana para seu destino (vale lembrar que não pode alterar o nome da pasta ZABBIX-TELIC). Vai acontecer uma copia do script para o particionamento do banco a copia do novo firewall que vai ficar ativo para o proximo reboot. Feito o reboot da maquina inicie o container do grafana com docker-compose up -d e dentro da parte web é preciso remover e instalar o plugin novamente.

# Documentação Geral 

# Segue o que cada script faz na Fricaire.
# update_proxy_remoto.sh Esse script é responsável por ler o ip atual e mudar a proxy, que fica alocado na Work. 

#!/bin/bash

############################################
# CONFIGURAÇÕES
############################################

SERVIDOR_PROXY="177.93.157.70"

ARQ_IP="/root/validalink/ip_atual.txt"

APACHE_CONF="/etc/apache2/sites-available/fricaire.conf"

WEBHOOK_URL="https://n8n.fourlink.net.br/webhook/9f39379a-bb80-408c-87dc-917ae46f62a1"

PORTA="9600"

DATA=$(date "+%Y-%m-%d %H:%M:%S")

echo "--------------------------------------"
echo "$DATA - EXECUÇÃO MANUAL DE TROCA DO PROXY"
echo "--------------------------------------"

############################################
# LÊ IP DO ARQUIVO
############################################

if [ ! -f "$ARQ_IP" ]; then
    echo "$DATA - arquivo ip_atual.txt não encontrado"
    exit 1
fi

NOVO_IP=$(cat $ARQ_IP | tr -d '[:space:]')

if [ -z "$NOVO_IP" ]; then
    echo "$DATA - IP vazio no arquivo"
    exit 1
fi

echo "$DATA - IP desejado: $NOVO_IP"

############################################
# PEGA IP ATUAL DO PROXY
############################################

IP_ATUAL=$(ssh root@$SERVIDOR_PROXY \
    "grep -m1 'BalancerMember http://' $APACHE_CONF | awk -F[/:] '{print \$4}'")

if [ -z "$IP_ATUAL" ]; then
    echo "$DATA - erro ao identificar IP atual no proxy"
    exit 1
fi

echo "$DATA - IP atual no proxy: $IP_ATUAL"

############################################
# VERIFICA SE PRECISA ALTERAR
############################################

if [ "$NOVO_IP" == "$IP_ATUAL" ]; then
    echo "$DATA - Proxy já está apontando para este IP. Nada a fazer."
    exit 0
fi

echo "$DATA - Alterando proxy: $IP_ATUAL -> $NOVO_IP"

############################################
# ALTERA PROXY REMOTO
############################################

ssh root@$SERVIDOR_PROXY << EOF

sed -i "s|BalancerMember http://$IP_ATUAL:$PORTA|BalancerMember http://$NOVO_IP:$PORTA|g" $APACHE_CONF

apachectl configtest
if [ \$? -ne 0 ]; then
    echo "ERRO config apache"
    exit 1
fi

systemctl restart apache2

EOF

if [ $? -ne 0 ]; then
    echo "$DATA - erro ao atualizar proxy"
    exit 1
fi

echo "$DATA - Proxy atualizado com sucesso"

############################################
# ENVIA WEBHOOK
############################################

MSG="Troca manual do proxy realizada \
IP antigo: $IP_ATUAL \
IP novo: $NOVO_IP"

curl -s -X POST $WEBHOOK_URL \
  -H "Content-Type: application/json" \
  -d "{\"text\":\"$MSG\"}" > /dev/null
echo "$DATA - Webhook enviado"
echo "--------------------------------------"

# leitor-hop.sh Este script é responsável por identificar a mudança do ip fixo para o ip da Starlink
#!/bin/bash
############################################
# CONFIGURAÇÕES
############################################
ARQ_HOP="/root/validalink/ultimo_hop.txt"
ARQ_STATUS="/root/validalink/hop_anterior.txt"
ARQ_IP="/root/validalink/ip_atual.txt"
LOG="/root/validalink/monitor_rota.log"
IP_FIXO="45.182.166.9"                  # IP público fixo do link principal
IP_CONTINGENCIA="172.18.183.36"         # IP a ser usado SEMPRE no failover (ajuste se necessário)
SCRIPT_EXTRA="/root/validalink/update_proxy_remoto.sh"
DATA=$(date "+%Y-%m-%d %H:%M:%S")

############################################
# FUNÇÃO — DESCOBRIR IP PUBLICO
############################################
obter_ip_publico() {
    for URL in \
        "https://api.ipify.org" \
        "https://ipv4.icanhazip.com" \
        "https://ifconfig.me/ip"
    do
        IP=$(curl -4 -s --max-time 4 "$URL" | tr -d '[:space:]')
        if echo "$IP" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
            echo "$IP"
            return
        fi
    done
    echo ""
}

############################################
# LÊ HOP ATUAL
############################################
HOP_ATUAL=$(cat "$ARQ_HOP" 2>/dev/null | tr -d '[:space:]')
if [ -z "$HOP_ATUAL" ]; then
    echo "$DATA - ultimo_hop.txt vazio ou inexistente" >> "$LOG"
    exit 0
fi

############################################
# LÊ HOP ANTERIOR
############################################
if [ -f "$ARQ_STATUS" ]; then
    HOP_ANTERIOR=$(cat "$ARQ_STATUS")
else
    echo "$HOP_ATUAL" > "$ARQ_STATUS"
    echo "$DATA - Primeiro registro de hop: $HOP_ATUAL" >> "$LOG"
    exit 0
fi

############################################
# SE NÃO MUDOU → NÃO FAZ NADA
############################################
if [ "$HOP_ATUAL" = "$HOP_ANTERIOR" ]; then
    echo "$DATA - Hop não mudou ($HOP_ATUAL)" >> "$LOG"
    exit 0
fi

echo "$DATA - MUDANÇA DE ROTA DETECTADA: $HOP_ANTERIOR → $HOP_ATUAL" >> "$LOG"

############################################
# DESCOBRE IP PUBLICO (só usado quando link principal está ativo)
############################################
IP_PUBLICO=$(obter_ip_publico)
if [ -z "$IP_PUBLICO" ]; then
    echo "$DATA - Erro ao obter IP público" >> "$LOG"
    exit 1
fi
if ! echo "$IP_PUBLICO" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "$DATA - IP inválido retornado: $IP_PUBLICO" >> "$LOG"
    exit 1
fi

############################################
# DECIDE QUAL IP USAR
############################################
if [ "$HOP_ATUAL" != "$IP_FIXO" ]; then
    # CENÁRIO 1 — FAILOVER (link principal caiu)
    echo "$DATA - Failover ativado (hop atual ≠ $IP_FIXO)" >> "$LOG"
    IP_USADO="$IP_CONTINGENCIA"
    echo "$DATA - Usando IP de contingência: $IP_USADO" >> "$LOG"
else
    # CENÁRIO 2 — Link principal restaurado
    echo "$DATA - Link principal restaurado (hop = $IP_FIXO)" >> "$LOG"
    IP_USADO="$IP_PUBLICO"
    echo "$DATA - Usando IP público detectado: $IP_USADO" >> "$LOG"
fi

# Salva o IP escolhido
echo "$IP_USADO" > "$ARQ_IP"
sync
sleep 1

# Verifica se salvou corretamente
SALVO=$(cat "$ARQ_IP" 2>/dev/null)
if [ "$SALVO" != "$IP_USADO" ]; then
    echo "$DATA - ERRO CRÍTICO: IP não foi salvo corretamente em $ARQ_IP (esperado: $IP_USADO, encontrado: $SALVO)" >> "$LOG"
    exit 1
fi

echo "$DATA - IP salvo com sucesso: $IP_USADO" >> "$LOG"

############################################
# EXECUTA ATUALIZAÇÃO DO PROXY REMOTO
############################################
echo "$DATA - Executando atualização do proxy remoto..." >> "$LOG"
bash "$SCRIPT_EXTRA" >> "$LOG" 2>&1
if [ $? -eq 0 ]; then
    echo "$DATA - Script $SCRIPT_EXTRA executado com sucesso" >> "$LOG"
else
    echo "$DATA - ERRO ao executar $SCRIPT_EXTRA (código de saída $?)" >> "$LOG"
fi

############################################
# ATUALIZA ESTADO PARA PRÓXIMA EXECUÇÃO
############################################
echo "$HOP_ATUAL" > "$ARQ_STATUS"
echo "$DATA - Processo finalizado com sucesso" >> "$LOG"

# Existe um serviço do Linux que roda em /etc/systemd/system# que roda em monitor_rota.sh

[Unit]
Description=Monitor de rota do cliente
After=network.target

[Service]
ExecStart=/root/validalink/monitor_rota.sh
Restart=always

[Install]
WantedBy=multi-user.target


#!/bin/bash

# ==== CONFIGURAÇÕES ====
DESTINO="8.8.8.8"
WEBHOOK_URL="https://n8n.fourlink.net.br/webhook/5c507ceb-a919-440c-a397-dbcafa6470f3"
#WEBHOOK_URL="https://n8n.alemnet.net.br/webhook/5c507ceb-a919-440c-a397-dbcafa6470f3"
ARQUIVO_STATUS="/root/validalink/ultimo_hop.txt"
LOG="/root/validalink/monitor_rota.log"

FOURLINK_IP="45.182.166.9"

# ==== ZABBIX ====
ZBX_SERVER="45.182.167.250"
ZBX_HOST="ROTA-FRICAIRE"

# ==== FUNÇÃO PARA PEGAR O PRIMEIRO HOP EXTERNO ====
obter_primeiro_hop_externo() {
    traceroute -n -w 2 -q 1 $DESTINO 2>/dev/null | awk '
        NR>=2 { 
            ip=$2
            if (ip ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) {
                if (!(ip ~ /^10\./ || ip ~ /^192\.168\./ || 
                      ip ~ /^172\.(1[6-9]|2[0-9]|3[0-1])\./)) {
                    print ip
                    exit
                }
            }
        }
    '
}

# ==== FUNÇÃO PARA NOME DO LINK ====
nome_do_link() {
    if [ "$1" == "$FOURLINK_IP" ]; then
        echo "Fourlink"
    else
        echo "Starlink"
    fi
}

# ==== LOOP ====
while true; do

    HOP_ATUAL=$(obter_primeiro_hop_externo)

    if [ -z "$HOP_ATUAL" ]; then
        echo "$(date '+%F %T') - Nenhum hop externo encontrado" >> "$LOG"
        sleep 300
        continue
    fi

    LINK_ATUAL=$(nome_do_link "$HOP_ATUAL")

    # Envia sempre o hop atual para o Zabbix
    zabbix_sender -z $ZBX_SERVER -s "$ZBX_HOST" -k rota.hop_atual -o "$HOP_ATUAL" >/dev/null
    zabbix_sender -z $ZBX_SERVER -s "$ZBX_HOST" -k rota.link_atual -o "$LINK_ATUAL" >/dev/null

    if [ ! -f "$ARQUIVO_STATUS" ]; then
        echo "$HOP_ATUAL" > "$ARQUIVO_STATUS"
        echo "$(date '+%F %T') - Hop inicial registrado: $HOP_ATUAL ($LINK_ATUAL)" >> "$LOG"
    else
        HOP_ANTERIOR=$(cat "$ARQUIVO_STATUS")
        LINK_ANTERIOR=$(nome_do_link "$HOP_ANTERIOR")

        if [ "$HOP_ATUAL" != "$HOP_ANTERIOR" ]; then

            echo "$(date '+%F %T') - ROTA MUDOU! $LINK_ANTERIOR → $LINK_ATUAL" >> "$LOG"

            MENSAGEM="A Fricaire está usando o link da $LINK_ATUAL"

            # webhook
            curl -s -X POST -H "Content-Type: application/json" \
                -d "{\"mensagem\": \"$MENSAGEM\", \"link_anterior\": \"$LINK_ANTERIOR\", \"link_atual\": \"$LINK_ATUAL\", \"hop_atual\": \"$HOP_ATUAL\"}" \
                "$WEBHOOK_URL" >/dev/null

            # zabbix alerta de mudança
            zabbix_sender -z $ZBX_SERVER -s "$ZBX_HOST" -k rota.mudou -o "De $LINK_ANTERIOR para $LINK_ATUAL" >/dev/null

            echo "$HOP_ATUAL" > "$ARQUIVO_STATUS"
        fi
    fi

    sleep 300
done

# Script check_wg.sh ele é responsável por checar se o Tunel com o servidor de proxy esta funcionando, quando ele perde o ping de conexão com o servidor de proxy ele reinicia o tunel, assim garante que fique funcionando o tunel.

#!/bin/bash

IP="10.0.0.1"

if ! ping -c 1 -W 2 $IP > /dev/null; then
    echo "$(date) - Ping falhou para $IP. Reiniciando WireGuard..." >> /var/log/wg-monitor.log
    systemctl restart --now wg-quick@wg0
else
    echo "$(date) - Ping OK para $IP" >> /var/log/wg-monitor.log
fi