#!/bin/bash

CONFIG_DIR="/etc/gre-tunnels"

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
    echo "Existing GRE tunnels installed by this script:"
    ls /usr/local/sbin/gre-*.sh 2>/dev/null | sed 's|.*/gre-||; s/.sh//'
    echo "---------------------------------------------"
    read -p "Enter the interface name you want to uninstall (example: gre1): " IFACE

    systemctl stop gre-${IFACE}.service
    systemctl disable gre-${IFACE}.service
    rm -f /etc/systemd/system/gre-${IFACE}.service
    rm -f /usr/local/sbin/gre-${IFACE}.sh
    ip tunnel del ${IFACE} 2>/dev/null
    systemctl daemon-reload

    echo "❌ GRE Tunnel ${IFACE} removed."
}


clear
echo "==========================="
echo "   GRE TUNNEL MANAGER"
echo "==========================="
echo "1) Install GRE Tunnel"
echo "2) Uninstall GRE Tunnel"
echo "==========================="
read -p "Select an option [1-2]: " OPTION

case $OPTION in
    1)
        install_gre
        ;;
    2)
        uninstall_gre
        ;;
    *)
        echo "Invalid option."
        ;;
esac
