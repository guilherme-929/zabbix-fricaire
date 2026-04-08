#!/usr/bin/env python3
import requests
import json
import csv
# Configurações da API do Zabbix
ZABBIX_API_URL = 'https://zabbix.fourlink.net.br/api_jsonrpc.php'
ZABBIX_API_TOKEN = 'c417863181df3f71a609d56f0fbec5804cc12b0157a51006e91883932c460436'  # Substitua pelo seu token da API
CSV_FILE = 'zabbix_hosts.csv'    # Nome do arquivo CSV que será gerado

def get_hosts(api_token):
    headers = {
        'Content-Type': 'application/json',
        'Authorization': f'Bearer {api_token}'
    }
    data = {
        "jsonrpc": "2.0",
        "method": "host.get",
        "params": {
            "output": ["hostid", "host"],
            "selectInterfaces": ["ip", "dns", "useip", "port", "type", "details"],
            "selectGroups": ["name"],
            "selectMacros": ["macro", "value"]
        },
        "id": 2,
        "auth": None
    }

    response = requests.post(ZABBIX_API_URL, headers=headers, data=json.dumps(data))

    if response.status_code != 200:
        raise Exception(f"Erro de conexão com a API Zabbix: {response.status_code}")

    response_data = response.json()

    if 'result' in response_data:
        return response_data['result']
    elif 'error' in response_data:
        raise Exception(f"Erro ao obter hosts: {response_data['error']['message']}")
    else:
        raise Exception("Resposta inesperada da API Zabbix")

def save_hosts_to_csv(hosts, filename):
    with open(filename, mode='w', newline='') as file:
        writer = csv.writer(file)

        # Novo cabeçalho com DNS, Use IP, SNMP Community e Macros
        writer.writerow(["Host Name", "Group", "IP Address", "DNS", "Use IP", "Port", "Interface Type", "SNMP Community", "Macros"])

        for host in hosts:
            host_name = host['host']
            groups = ', '.join([group['name'] for group in host['groups']])
            interfaces = host['interfaces']
            macros = host.get('macros', [])

            # Transforma as macros em uma string: {$MACRO}=VALOR;...
            macro_str = '; '.join([f"{m['macro']}={m['value']}" for m in macros])

            for interface in interfaces:
                ip_address = interface.get('ip', 'N/A')
                dns = interface.get('dns', 'N/A')
                use_ip = interface.get('useip', '1')
                port = interface.get('port', 'N/A')
                interface_type = interface.get('type', 'N/A')

                interface_map = {
                    "1": "Agent",
                    "2": "SNMP",
                    "3": "IPMI",
                    "4": "JMX",
                    "5": "SSH",
                    "6": "Telnet"
                }
                interface_name = interface_map.get(str(interface_type), "Desconhecido")

                # SNMP community está em interface.details
                snmp_community = ''
                if interface_type == 2:
                    snmp_community = interface.get("details", {}).get("community", "")

                writer.writerow([
                    host_name, groups, ip_address, dns, use_ip,
                    port, interface_name, snmp_community, macro_str
                ])

def main():
    try:
        hosts = get_hosts(ZABBIX_API_TOKEN)
        save_hosts_to_csv(hosts, CSV_FILE)
        print(f"Informações dos hosts salvas no arquivo {CSV_FILE}")
    except Exception as e:
        print(f"Erro: {e}")

if __name__ == '__main__':
    main()