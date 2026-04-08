#!/bin/bash
set -euo pipefail

CRON_FILE="/etc/cron.d/zabbix"
BACKUP_DIR="/root"
TIMESTAMP="$(date +%F_%H%M%S)"
BACKUP_FILE="${BACKUP_DIR}/zabbix.cron.bak.${TIMESTAMP}"

echo "Executando como: $(id -un)"
if [ "$(id -u)" -ne 0 ]; then
  echo "ERRO: execute este script como root."
  exit 1
fi

# Faz backup se já existir
if [ -f "${CRON_FILE}" ]; then
  echo "Fazendo backup de ${CRON_FILE} -> ${BACKUP_FILE}"
  cp "${CRON_FILE}" "${BACKUP_FILE}"
fi

# Cria/reescreve o arquivo de cron
cat > "${CRON_FILE}" <<'EOF'
# Crons para ZABBIX (arquivo gerado automaticamente)
0 1 * * * root /bin/sh /root/zabbix/particionamento.sh
0 4 * * 4 root /bin/sh /root/zabbix/backup.sh
0 1 * * 6 root /bin/sh /root/zabbix/envio.sh

EOF

# Permissões corretas
chmod 644 "${CRON_FILE}"
chown root:root "${CRON_FILE}"

# tenta recarregar serviço de cron (não é crítico se falhar)
if command -v systemctl >/dev/null 2>&1; then
  systemctl try-reload-or-restart cron.service 2>/dev/null || \
  systemctl try-reload-or-restart crond.service 2>/dev/null || true
fi

echo "Arquivo ${CRON_FILE} criado/atualizado com sucesso."
