#!/bin/bash

CONFIG_DIR="/etc/gre-tunnels"
BACKUP_DIR="/etc/gre-tunnels/backup"

function create_systemd_service() {
    local IFACE=$1

    cat > /etc/systemd/system/gre-${IFACE}.service <<EOF
[Unit]
Description=GRE Tunnel: $IFACE
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/gre-${IFACE}.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
}

function create_gre_script() {
    local IFACE=$1
    local LOCAL_IP=$2
    local REMOTE_IP=$3
    local PRIV_IP=$4

    mkdir -p "$CONFIG_DIR"

    cat > /usr/local/sbin/gre-${IFACE}.sh <<EOF
#!/bin/bash
ip tunnel del ${IFACE} 2>/dev/null
ip tunnel add ${IFACE} mode gre local ${LOCAL_IP} remote ${REMOTE_IP} ttl 255
ip link set ${IFACE} up
ip addr add ${PRIV_IP} dev ${IFACE}
EOF

    chmod +x /usr/local/sbin/gre-${IFACE}.sh
}

function install_gre() {
    read -p "Enter the interface name (example: gre1): " IFACE
    read -p "Enter the local IP (your public IP): " LOCAL_IP
    read -p "Enter the remote IP (target public IP): " REMOTE_IP
    read -p "Enter the private IP with mask (example: 10.0.0.1/24): " PRIV_IP

    create_gre_script "$IFACE" "$LOCAL_IP" "$REMOTE_IP" "$PRIV_IP"
    create_systemd_service "$IFACE"

    systemctl daemon-reload
    systemctl enable gre-${IFACE}.service
    systemctl start gre-${IFACE}.service

    echo "✅ GRE Tunnel ${IFACE} installed and enabled on boot."
}

function uninstall_gre() {
    echo "Existing GRE tunnels:"
    ls /usr/local/sbin/gre-*.sh 2>/dev/null | sed 's|.*/gre-||; s/.sh//'
    echo "---------------------------------------------"
    read -p "Enter the interface name to uninstall (example: gre1): " IFACE

    systemctl stop gre-${IFACE}.service
    systemctl disable gre-${IFACE}.service
    rm -f /etc/systemd/system/gre-${IFACE}.service
    rm -f /usr/local/sbin/gre-${IFACE}.sh
    ip tunnel del ${IFACE} 2>/dev/null
    systemctl daemon-reload

    echo "❌ GRE Tunnel ${IFACE} removed."
}

function list_tunnels() {
    echo "🔍 Active GRE Tunnels:"
    ip tunnel show | grep gre
}

function show_status() {
    echo "📋 GRE Tunnel systemd status:"
    systemctl list-units --type=service | grep gre-
}

function test_connectivity() {
    read -p "Enter destination IP to ping (usually private IP on other side): " DST
    ping -c 4 "$DST"
}

function edit_tunnel() {
    read -p "Enter the interface name to edit (example: gre1): " IFACE
    read -p "New Local IP: " LOCAL
    read -p "New Remote IP: " REMOTE
    read -p "New Private IP/Mask: " PRIV

    create_gre_script "$IFACE" "$LOCAL" "$REMOTE" "$PRIV"
    systemctl restart gre-${IFACE}.service
    echo "🛠 Tunnel $IFACE updated and restarted."
}

function backup_configs() {
    mkdir -p "$BACKUP_DIR"
    cp /usr/local/sbin/gre-*.sh "$BACKUP_DIR" 2>/dev/null
    cp /etc/systemd/system/gre-*.service "$BACKUP_DIR" 2>/dev/null
    echo "💾 All GRE configs backed up to $BACKUP_DIR"
}

function delete_all_gres() {
    echo "⚠️ Are you sure you want to delete ALL GRE tunnels? (y/n)"
    read CONFIRM
    if [[ "$CONFIRM" == "y" ]]; then
        for FILE in /usr/local/sbin/gre-*.sh; do
            IFACE=$(basename "$FILE" | sed 's/gre-//; s/.sh//')
            systemctl stop gre-${IFACE}.service
            systemctl disable gre-${IFACE}.service
            rm -f /etc/systemd/system/gre-${IFACE}.service
            rm -f /usr/local/sbin/gre-${IFACE}.sh
            ip tunnel del ${IFACE} 2>/dev/null
        done
        systemctl daemon-reload
        echo "❌ All GRE tunnels removed."
    else
        echo "❎ Operation canceled."
    fi
}

function optimize_tunnel() {
    read -p "Enter the interface name to optimize (example: gre1): " IFACE
    echo "⚙️ Optimizing GRE tunnel $IFACE..."

    # TTL and Keepalive
    ip tunnel change ${IFACE} ttl 255 keepalive 5 4 2>/dev/null

    # Enable IP Forwarding
    sysctl -w net.ipv4.ip_forward=1 >/dev/null

    # Network performance tunings
    sysctl -w net.core.rmem_max=26214400 >/dev/null
    sysctl -w net.core.wmem_max=26214400 >/dev/null
    sysctl -w net.ipv4.tcp_window_scaling=1 >/dev/null

    echo "✅ Tunnel $IFACE optimized successfully."
}

# Menu
clear
echo "=============================="
echo "      GRE TUNNEL MANAGER"
echo "=============================="
echo "1) Install GRE Tunnel"
echo "2) Uninstall GRE Tunnel"
echo "3) Show Tunnel Status"
echo "4) List GRE Tunnels"
echo "5) Test Tunnel Connectivity"
echo "6) Edit Existing Tunnel"
echo "7) Backup Tunnel Configurations"
echo "8) Delete All GRE Tunnels"
echo "9) Optimize GRE Tunnel"
echo "=============================="
read -p "Select an option [1-9]: " OPTION

case $OPTION in
    1) install_gre ;;
    2) uninstall_gre ;;
    3) show_status ;;
    4) list_tunnels ;;
    5) test_connectivity ;;
    6) edit_tunnel ;;
    7) backup_configs ;;
    8) delete_all_gres ;;
    9) optimize_tunnel ;;
    *) echo "❌ Invalid option." ;;
esac
