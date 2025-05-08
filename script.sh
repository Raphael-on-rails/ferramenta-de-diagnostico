#!/bin/bash


RELATORIO="relatorio_dispositivos.html"


cat << EOF > "$RELATORIO"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Relatório Completo da Rede</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f4f4f4; }
        h1, h2 { color: #333; }
        table { width: 100%; border-collapse: collapse; margin-bottom: 30px; background-color: #fff; }
        th, td { padding: 12px; border: 1px solid #ddd; text-align: left; }
        th { background-color: #333; color: #fff; }
        .online { color: green; font-weight: bold; }
        .offline { color: red; font-weight: bold; }
        .footer { text-align: center; margin-top: 20px; color: #777; }
    </style>
</head>
<body>
    <h1>Relatório Completo da Rede</h1>
    <p>Data: $(date)</p>

    <canvas id="statusChart" width="585" height="585"></canvas>

    <script>
        const ctx = document.getElementById('statusChart').getContext('2d');
        const statusChart = new Chart(ctx, {
            type: 'pie',
            data: {
                labels: ['Online', 'Offline'],
                datasets: [{
                    label: 'Status dos Dispositivos',
                    data: [0, 0], // Será preenchido pelo script Bash
                    backgroundColor: ['green', 'red'],
                    borderColor: ['#fff', '#fff'],
                    borderWidth: 1
                }]
            },
            options: { responsive: true }
        });
    </script>
EOF

# Declare seus dispositivos
declare -A dispositivos=(
    ["PC"]="192.168.0.2"
    ["notebook"]="192.168.0.3"
    ["Modem"]="192.168.0.1"
)

online_count=0
offline_count=0


get_mac() {
    local ip="$1"
    arp -n "$ip" | awk '/:/{print $3}' | head -n 1
}


check_device() {
    local nome="$1"
    local ip="$2"

    echo "Verificando $nome ($ip)..."

    ping -c 1 -W 1 "$ip" &>/dev/null
    if [[ $? -eq 0 ]]; then
        local status="<span class='online'>ONLINE</span>"
        ((online_count++))
        local latencia
        latencia=$(ping -c 1 -W 1 "$ip" | grep 'time=' | awk -F'time=' '{print $2}' | awk '{print $1}')
        local mac
        mac=$(get_mac "$ip")
        [[ -z "$mac" ]] && mac="Não encontrado"

        # Escolha: scanner rápido ou deep scan
        read -p "Deseja fazer Deep Scan (todas as portas) no $nome? (s/n): " escolha
        if [[ "$escolha" == "s" ]]; then
            echo "Iniciando Deep Scan em $ip (pode demorar)..."
            portas=$(nmap -Pn -p- "$ip" | awk '/^[0-9]+\/tcp/ {print $1 " - " $2 " - " $3}' | xargs -d'\n' -I {} echo "<li>{}</li>" | tr -d '\r')
        else
            portas=$(nmap -Pn --top-ports 10 "$ip" | awk '/^[0-9]+\/tcp/ {print $1 " - " $2 " - " $3}' | xargs -d'\n' -I {} echo "<li>{}</li>" | tr -d '\r')
        fi

        cat << EOF >> "$RELATORIO"
        <h2>$nome</h2>
        <table>
            <tr><th>IP</th><td>$ip</td></tr>
            <tr><th>Status</th><td>$status</td></tr>
            <tr><th>Latência</th><td>${latencia} ms</td></tr>
            <tr><th>MAC Address</th><td>$mac</td></tr>
            <tr><th>Portas abertas</th><td><ul>$portas</ul></td></tr>
        </table>
EOF
    else
        local status="<span class='offline'>OFFLINE</span>"
        ((offline_count++))
        cat << EOF >> "$RELATORIO"
        <h2>$nome</h2>
        <table>
            <tr><th>IP</th><td>$ip</td></tr>
            <tr><th>Status</th><td>$status</td></tr>
            <tr><th>Latência</th><td>N/A</td></tr>
            <tr><th>MAC Address</th><td>N/A</td></tr>
            <tr><th>Portas abertas</th><td>N/A (dispositivo offline)</td></tr>
        </table>
EOF
    fi
}

# Loop
for nome in "${!dispositivos[@]}"; do
    check_device "$nome" "${dispositivos[$nome]}"
done


cat << EOF >> "$RELATORIO"
<script>
    statusChart.data.datasets[0].data = [$online_count, $offline_count];
    statusChart.update();
</script>
EOF

# Fim
cat << EOF >> "$RELATORIO"
    <div class="footer">Raphael-on-Rails</div>
</body>
</html>
EOF

echo ""
echo "Relatório HTML gerado: $RELATORIO"

if command -v xdg-open &>/dev/null; then
    xdg-open "$RELATORIO"
elif command -v firefox &>/dev/null; then
    firefox "$RELATORIO"
elif command -v google-chrome &>/dev/null; then
    google-chrome "$RELATORIO"
else
    echo "Relatório gerado, mas não foi possível abrir automaticamente."
fi


