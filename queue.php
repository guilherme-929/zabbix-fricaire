<?php
/**
 * Este arquivo processa os dados armazenados na fila e os envia para o webhook.
 * Agora suporta múltiplos canais usando ID dinâmico.
 * @author Telic Technologies
 * @license PRIVATE
 */

function send_to_webhook($data) {
    if (empty($data['token'])) {
        echo "❌ Erro: token não encontrado no payload.\n";
        return ['response' => null, 'http_code' => 400];
    }

    $webhook_url = "https://n8n.fourlink.net.br/webhook/" . urlencode($data['token']);

    $ch = curl_init($webhook_url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));

    $response = curl_exec($ch);
    $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);

    if ($response === false) {
        $error = curl_error($ch);
        echo "❌ CURL ERROR: $error\n";
    }

    curl_close($ch);

    echo "ℹ Enviando para token: " . $data['token'] . " | HTTP $http_code\n";

    return ['response' => $response, 'http_code' => $http_code];
}

function process_fila() {
    $diretorio = __DIR__ . '/fila';

    if (!is_dir($diretorio)) {
        mkdir($diretorio, 0755, true);
    }

    while (true) {
        $arquivos = glob($diretorio . '/*.json');

        foreach ($arquivos as $arquivo) {
            $payload = json_decode(file_get_contents($arquivo), true);

            if ($payload === null) {
                echo "❌ Erro ao decodificar o JSON do arquivo: $arquivo\n";
                continue;
            }

            // Envia para o webhook com base no canal_id
            $result = send_to_webhook($payload);
            $http_code = $result['http_code'];

            if ($http_code === 200) {
                echo "✅ Mensagem enviada com sucesso: $arquivo\n";
                if (unlink($arquivo)) {
                    echo "🗑 Arquivo removido: $arquivo\n";
                }
            } else {
                echo "⚠ Erro ao enviar mensagem (HTTP $http_code). Mantendo na fila: $arquivo\n";
                sleep(5);
                break;
            }
        }

        sleep(1);
    }
}

process_fila();


