#!/bin/bash

# GRE Tunnel Manager - Advanced Version

CONFIG_DIR="/etc/gre-tunnels"
SERVICE_DIR="/etc/systemd/system"
LOG_FILE="/var/log/gre-tunnel-manager.log"

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;36m'
YELLOW='\033[1;33m'
MAGENTA="\e[35m"
CYAN='\033[0;36m'
NC='\033[0m' # No Color

function log_msg() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE"
}

function print_success() {
    echo -e "${GREEN}[✔] $1${NC}"
}

function print_error() {
    echo -e "${RED}[✘] $1${NC}"
}

function print_info() {
    echo -e "${BLUE}[i] $1${NC}"
}

function ensure_config_dir() {
    if [ ! -d "$CONFIG_DIR" ]; then
        mkdir -p "$CONFIG_DIR"
    fi
}

function create_gre_script() {
    local IFACE=$1
    local LOCAL_IP=$2
    local REMOTE_IP=$3
    local PRIV_IP=$4
    local REMOTE_PRIV_IP=$5
    local MTU=$6

    ensure_config_dir

    cat > /usr/local/sbin/gre-${IFACE}.sh <<EOF
#!/bin/bash
ip tunnel del ${IFACE} 2>/dev/null
ip tunnel add ${IFACE} mode gre local ${LOCAL_IP} remote ${REMOTE_IP} ttl 255
ip link set ${IFACE} mtu ${MTU}
ip link set ${IFACE} up
ip addr add ${PRIV_IP} dev ${IFACE}
ip route add ${REMOTE_PRIV_IP} dev ${IFACE}
EOF

    chmod +x /usr/local/sbin/gre-${IFACE}.sh
}

# Get server IP
SERVER_IP=$(hostname -I | awk '{print $1}')

# Fetch server country using ip-api.com
SERVER_COUNTRY=$(curl --max-time 3 -sS "http://ip-api.com/json/$SERVER_IP" | jq -r '.country')

# Fetch server isp using ip-api.com 
SERVER_ISP=$(curl --max-time 3 -sS "http://ip-api.com/json/$SERVER_IP" | jq -r '.isp')

display_server_info() {
    echo -e "${GREEN}=============================="  
    echo -e "${CYAN}Server Country:${NC} $SERVER_COUNTRY"
    echo -e "${CYAN}Server IP:${NC} $SERVER_IP"
    echo -e "${CYAN}Server ISP:${NC} $SERVER_ISP"
}

function create_systemd_service() {
    local IFACE=$1

    cat > ${SERVICE_DIR}/gre-${IFACE}.service <<EOF
[Unit]
Description=GRE Tunnel: ${IFACE}
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

function install_gre() {
    echo "Installing new GRE tunnel..."
    read -p "Interface name (e.g. gre1): " IFACE
    if [[ -z "$IFACE" ]]; then
        print_error "Interface name cannot be empty."
        return
    fi

    read -p "Local public IP (0.0.0.0): " LOCAL_IP
    read -p "Remote public IP: " REMOTE_IP
    read -p "local Private IP (e.g. 10.0.0.1/24): " PRIV_IP
    read -p "Remote private IP (e.g. 10.0.0.2): " REMOTE_PRIV_IP
    read -p "MTU (default 1400): " MTU
    MTU=${MTU:-1400}

    # Save config
    ensure_config_dir
    cat > "$CONFIG_DIR/${IFACE}.conf" <<EOF
IFACE=${IFACE}
LOCAL_IP=${LOCAL_IP}
REMOTE_IP=${REMOTE_IP}
PRIV_IP=${PRIV_IP}
REMOTE_PRIV_IP=${REMOTE_PRIV_IP}
MTU=${MTU}
EOF

    create_gre_script "$IFACE" "$LOCAL_IP" "$REMOTE_IP" "$PRIV_IP" "$REMOTE_PRIV_IP" "$MTU"
    create_systemd_service "$IFACE"

    systemctl daemon-reexec
    systemctl daemon-reload
    systemctl enable gre-${IFACE}.service
    systemctl start gre-${IFACE}.service

    if [[ $? -eq 0 ]]; then
        print_success "GRE tunnel ${IFACE} installed and started."
        log_msg "Installed GRE tunnel ${IFACE} (${LOCAL_IP} -> ${REMOTE_IP})"
    else
        print_error "Failed to start tunnel ${IFACE}."
        log_msg "Failed to start GRE tunnel ${IFACE}"
    fi
}

function uninstall_gre() {
    echo "Installed GRE tunnels:"
    ls "$CONFIG_DIR"/*.conf 2>/dev/null | xargs -n1 basename | sed 's/.conf//'
    read -p "Enter tunnel interface to uninstall (e.g. gre1): " IFACE
    if [[ ! -f "$CONFIG_DIR/${IFACE}.conf" ]]; then
        print_error "Tunnel config not found."
        return
    fi

    systemctl stop gre-${IFACE}.service
    systemctl disable gre-${IFACE}.service
    rm -f ${SERVICE_DIR}/gre-${IFACE}.service
    rm -f /usr/local/sbin/gre-${IFACE}.sh
    rm -f "$CONFIG_DIR/${IFACE}.conf"
    ip tunnel del ${IFACE} 2>/dev/null
    systemctl daemon-reload

    print_success "GRE tunnel ${IFACE} removed."
    log_msg "Uninstalled GRE tunnel ${IFACE}"
}

function restart_gre() {
    read -p "Enter tunnel interface to restart (e.g. gre1): " IFACE
    systemctl restart gre-${IFACE}.service
    if [[ $? -eq 0 ]]; then
        print_success "Tunnel ${IFACE} restarted."
        log_msg "Restarted GRE tunnel ${IFACE}"
    else
        print_error "Failed to restart tunnel ${IFACE}."
        log_msg "Failed to restart GRE tunnel ${IFACE}"
    fi
}

function optimize_tunnel() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "\e[31m[ERROR]\e[0m Run as root." >&2
        return 1
    fi

    read -rp "Enter GRE interface name (e.g. gre1): " IFACE
    [[ ! "$IFACE" =~ ^[a-zA-Z0-9_]+$ ]] && { echo -e "\e[31m[ERROR]\e[0m Invalid interface name."; return 1; }
    ip link show "$IFACE" &>/dev/null || { echo -e "\e[31m[ERROR]\e[0m Interface not found."; return 1; }

    echo -e "\e[36m[*] Applying advanced optimizations for VPN over GRE: $IFACE\e[0m"

    apply_sysctl() {
        local key="$1"
        local value="$2"
        sysctl -qw "$key=$value" && echo -e "\e[32m✓ $key = $value\e[0m" || echo -e "\e[33m✗ Failed: $key = $value\e[0m"
    }

    # Interface-specific
    apply_sysctl "net.ipv4.conf.${IFACE}.rp_filter" 0
    apply_sysctl "net.ipv4.conf.${IFACE}.accept_local" 1
    apply_sysctl "net.ipv4.conf.${IFACE}.accept_redirects" 0
    apply_sysctl "net.ipv4.conf.${IFACE}.send_redirects" 0
    apply_sysctl "net.ipv4.conf.${IFACE}.log_martians" 0
    apply_sysctl "net.ipv4.conf.${IFACE}.proxy_arp" 1
    apply_sysctl "net.ipv4.conf.${IFACE}.forwarding" 1

    # MTU optimization (dynamic)
    ip link set dev "$IFACE" mtu 1300
    echo -e "\e[32m✓ MTU set to 1300 on $IFACE\e[0m"

    # General
    apply_sysctl "net.ipv4.ip_forward" 1
    apply_sysctl "net.ipv4.tcp_no_metrics_save" 1
    apply_sysctl "net.ipv4.tcp_mtu_probing" 1    # Auto-adjust MSS
    apply_sysctl "net.ipv4.route.flush" 1

    # TCP Performance
    apply_sysctl "net.ipv4.tcp_window_scaling" 1
    apply_sysctl "net.ipv4.tcp_timestamps" 0
    apply_sysctl "net.ipv4.tcp_sack" 1
    apply_sysctl "net.core.rmem_default" 1048576
    apply_sysctl "net.core.wmem_default" 1048576
    apply_sysctl "net.core.rmem_max" 67108864
    apply_sysctl "net.core.wmem_max" 67108864
    apply_sysctl "net.ipv4.tcp_rmem" "4096 87380 67108864"
    apply_sysctl "net.ipv4.tcp_wmem" "4096 65536 67108864"

    # Congestion Control (use BBR if available)
    if sysctl net.ipv4.tcp_congestion_control 2>/dev/null | grep -q bbr; then
        apply_sysctl "net.ipv4.tcp_congestion_control" "bbr"
    else
        apply_sysctl "net.ipv4.tcp_congestion_control" "cubic"
    fi

    # Fast recovery, ECN, and resilience
    apply_sysctl "net.ipv4.tcp_ecn" 1
    apply_sysctl "net.ipv4.tcp_fastopen" 3
    apply_sysctl "net.ipv4.tcp_syn_retries" 5
    apply_sysctl "net.ipv4.tcp_retries2" 8
    apply_sysctl "net.ipv4.tcp_keepalive_time" 20
    apply_sysctl "net.ipv4.tcp_keepalive_intvl" 10
    apply_sysctl "net.ipv4.tcp_keepalive_probes" 5

    # Save settings permanently
    CONF="/etc/sysctl.d/99-${IFACE}-vpn.conf"
    cat > "$CONF" <<EOF
# Advanced GRE VPN settings for $IFACE

net.ipv4.conf.${IFACE}.rp_filter = 0
net.ipv4.conf.${IFACE}.accept_local = 1
net.ipv4.conf.${IFACE}.accept_redirects = 0
net.ipv4.conf.${IFACE}.send_redirects = 0
net.ipv4.conf.${IFACE}.log_martians = 0
net.ipv4.conf.${IFACE}.proxy_arp = 1
net.ipv4.conf.${IFACE}.forwarding = 1

net.ipv4.ip_forward = 1
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_mtu_probing = 1
net.ipv4.route.flush = 1

net.core.rmem_default = 1048576
net.core.wmem_default = 1048576
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_sack = 1

net.ipv4.tcp_ecn = 1
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_syn_retries = 5
net.ipv4.tcp_retries2 = 8
net.ipv4.tcp_keepalive_time = 20
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 5

net.ipv4.tcp_congestion_control = $(sysctl -n net.ipv4.tcp_congestion_control)
EOF

    sysctl --system >/dev/null 2>&1 && echo -e "\e[32m[✓] Settings saved and applied.\e[0m" || echo -e "\e[33m[!] Warning: Reload failed.\e[0m"

    echo -e "\e[36m[*] VPN GRE Tunnel '$IFACE' is now fully optimized.\e[0m"
}

function find_best_mtu() {
    read -p "Enter remote IP to test MTU: " REMOTE_IP
    if [[ -z "$REMOTE_IP" ]]; then
        print_error "Remote IP cannot be empty."
        return
    fi

    echo -e "${YELLOW}Finding optimal MTU to $REMOTE_IP...${NC}"
    MAX_MTU=1472
    MIN_MTU=1200
    STEP=10
    MTU=$MAX_MTU

    while [ $MTU -ge $MIN_MTU ]; do
        if ping -c 1 -M do -s $MTU $REMOTE_IP &>/dev/null; then
            print_success "Best working MTU found: $((MTU + 28)) (raw MTU: $MTU)"
            return
        fi
        MTU=$((MTU - STEP))
    done

    print_error "Failed to find optimal MTU"
}

function list_tunnels() {
    local BLUE="\e[34m"
    local GREEN="\e[32m"
    local RED="\e[31m"
    local CYAN="\e[36m"
    local YELLOW="\e[33m"
    local NC="\e[0m"

    echo -e "${BLUE}Installed GRE tunnels:${NC}"

    shopt -s nullglob
    local tunnels=("$CONFIG_DIR"/*.conf)
    shopt -u nullglob

    if [ ${#tunnels[@]} -eq 0 ]; then
        echo -e "${RED}No tunnels found.${NC}"
        return
    fi

    for conf in "${tunnels[@]}"; do
        IFACE=$(basename "$conf" .conf)

        # Check interface state
                IFACE_INFO=$(ip link show dev "$IFACE" 2>/dev/null)
                   if [[ "$IFACE_INFO" == *"<"*UP*","*LOWER_UP*">"* ]]; then
                     STATE="${GREEN}UP${NC}"
                   elif [[ "$IFACE_INFO" == *"<"*UP*">"* ]]; then
                       STATE="${YELLOW}Partially UP${NC}"  # UP-LOWER_UP
                   else
                       STATE="${RED}DOWN${NC}"
                   fi

        # Read RX and TX bytes; fallback to 0 if not available
        RX=$(cat /sys/class/net/"$IFACE"/statistics/rx_bytes 2>/dev/null || echo "0")
        TX=$(cat /sys/class/net/"$IFACE"/statistics/tx_bytes 2>/dev/null || echo "0")

        RX_MB=$(awk "BEGIN {printf \"%.2f\", $RX/1024/1024}")
        TX_MB=$(awk "BEGIN {printf \"%.2f\", $TX/1024/1024}")

        # Print interface info with box-like separator
        echo -e "${CYAN}========================================${NC}"
        echo -e "${YELLOW}Interface:${NC} ${IFACE}"
        echo -e "${YELLOW}State:    ${NC} ${STATE}"
        echo -e "${YELLOW}RX:       ${NC} ${RX_MB} MB"
        echo -e "${YELLOW}TX:       ${NC} ${TX_MB} MB"
        echo -e "${CYAN}========================================${NC}\n"
    done
}

function show_tunnel_status() {
    local GREEN="\e[32m"
    local RED="\e[31m"
    local CYAN="\e[36m"
    local NC="\e[0m"

    read -p "🔍 Enter tunnel interface (e.g. gre1): " IFACE

    if ! ip tunnel show "$IFACE" &>/dev/null; then
        echo -e "${RED}✘ Tunnel '${IFACE}' not found.${NC}"
        return
    fi

    # key info
    local TUNNEL_INFO
    TUNNEL_INFO=$(ip tunnel show "$IFACE" | head -n 1)

    local IP4
    IP4=$(ip -4 addr show dev "$IFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' | head -n 1)

    local RX=$(cat /sys/class/net/"$IFACE"/statistics/rx_bytes 2>/dev/null || echo 0)
    local TX=$(cat /sys/class/net/"$IFACE"/statistics/tx_bytes 2>/dev/null || echo 0)

    local RX_MB=$(awk "BEGIN {printf \"%.1f\", $RX/1024/1024}")
    local TX_MB=$(awk "BEGIN {printf \"%.1f\", $TX/1024/1024}")

    # beutiful coler
    echo -e "${CYAN}┌─ Tunnel Status: ${IFACE} ─────────────────────┐${NC}"
    echo -e " ${GREEN}✓ Info:   ${NC}${TUNNEL_INFO}"
    echo -e " ${GREEN}✓ IPv4:   ${NC}${IP4:-N/A}"
    echo -e " ${GREEN}✓ RX/TX:  ${NC}${RX_MB} MB ↓ / ${TX_MB} MB ↑"
    echo -e "${CYAN}└──────────────────────────────────────────────┘${NC}"
}

function enable_disable_tunnel() {
    read -p "Enter tunnel interface to toggle (e.g. gre1): " IFACE
    if [[ ! -f "$CONFIG_DIR/${IFACE}.conf" ]]; then
        print_error "Tunnel config not found."
        return
    fi
    read -p "Choose action: 1) Enable 2) Disable: " ACTION
    case $ACTION in
        1)
            systemctl start gre-${IFACE}.service
            systemctl enable gre-${IFACE}.service
            print_success "Tunnel ${IFACE} enabled."
            log_msg "Enabled GRE tunnel ${IFACE}"
            ;;
        2)
            systemctl stop gre-${IFACE}.service
            systemctl disable gre-${IFACE}.service
            print_success "Tunnel ${IFACE} disabled."
            log_msg "Disabled GRE tunnel ${IFACE}"
            ;;
        *)
            print_error "Invalid action."
            ;;
    esac
}

function show_log() {
    if [ ! -f "$LOG_FILE" ]; then
        print_info "No logs found."
        return
    fi
    echo -e "${BLUE}---- GRE Tunnel Manager Logs ----${NC}"
    tail -n 20 "$LOG_FILE"
}

# === Menu ===

function show_menu() {
    clear
    echo -e "${GREEN}=============================="
    echo "       ____ ____   _____
      / ___|  _ \ | ____|
     | |  _| |_)| |  _|
     | |_| |  __/ | |__|
      \____|_| \_\|_____|

       G R E   I P V 4

==============================
       creator: agha ahmad
       telegram: @Special_WE"
    display_server_info
    echo -e "${GREEN}==============================${NC}"
    echo -e "${GREEN}1) Install GRE Tunnel"
    echo -e "${RED}2) Uninstall GRE Tunnel"
    echo -e "${YELLOW}3) Restart GRE Tunnel"
    echo -e "${GREEN}4) Optimize GRE Tunnel"
    echo -e "${GREEN}5) Find Best MTU"
    echo -e "${GREEN}6) List Tunnels"
    echo -e "${GREEN}7) Show Tunnel Status"
    echo -e "${GREEN}8) Enable/Disable Tunnel"
    echo -e "${GREEN}9) Show Logs"
    echo -e "${GREEN}0) Exit${NC}"
    echo -e "${GREEN}==============================${NC}"
    read -p "Choose an option: " OPTION
}

# === Main Loop ===
while true; do
    show_menu
    case $OPTION in
        1) install_gre ;;
        2) uninstall_gre ;;
        3) restart_gre ;;
        4) optimize_tunnel ;;
        5) find_best_mtu ;;
        6) list_tunnels ;;
        7) show_tunnel_status ;;
        8) enable_disable_tunnel ;;
        9) show_log ;;
        0) echo -e "${GREEN}Bye!${NC}"; exit 0 ;;
        *) print_error "Invalid option." ;;
    esac
    read -p "Press Enter to continue..." key
done
