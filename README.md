GRE Tunnel for Private IPv4 Networks

    A lightweight, production-ready Bash script for building secure GRE Tunnels between Linux servers over IPv4.
    Simplify internal routing and private connectivity with automated configuration.



🚀 Features

    Fully automated GRE tunnel setup between two Linux servers (Ubuntu/Debian)

    Supports both static and dynamic IP endpoints

    Optimized for private IPv4 communications

    Automatically configures:

        ip tunnel

        ip route

        iptables (optional)

        persist after reboot (optional)

    Minimal dependencies (iproute2, bash)

    Clean and fast. Less than 100 lines of bash.

📖 Usage
🔧 Quick Install

bash <(curl -Ls https://raw.githubusercontent.com/asphalte-khaki/IPV4-privet.Tunell/main/gre-tunnel.sh)

📝 How It Works

    Creates a GRE Tunnel device gre1

    Assigns IP addresses to both tunnel endpoints

    Updates system routes to route traffic through the tunnel

    (Optional) Configures iptables rules for isolation

    Saves configuration to survive system reboot

📂 Directory Structure

/
├── gre-tunnel.sh   # Main GRE Tunnel automation script
├── README.md       # This documentation

⚙️ Requirements

    Linux (Debian / Ubuntu recommended)

    iproute2

    curl

    Root privileges (sudo)

🚦 Example
1️⃣ On Server A:
Role	Public IP	Private Tunnel IP
Local	1.1.1.1	192.168.100.1

bash <(curl -Ls https://raw.githubusercontent.com/asphalte-khaki/IPV4-privet.Tunell/main/gre-tunnel.sh)
# When asked: 
# Remote Peer Public IP: 2.2.2.2
# Local Tunnel IP: 192.168.100.1
# Remote Tunnel IP: 192.168.100.2

2️⃣ On Server B:
Role	Public IP	Private Tunnel IP
Remote	2.2.2.2	192.168.100.2

bash <(curl -Ls https://raw.githubusercontent.com/asphalte-khaki/IPV4-privet.Tunell/main/gre-tunnel.sh)
# When asked: 
# Remote Peer Public IP: 1.1.1.1
# Local Tunnel IP: 192.168.100.2
# Remote Tunnel IP: 192.168.100.1

✅ After setup:

ping 192.168.100.2  # From A to B

🛡 Security Considerations

    GRE itself does not encrypt traffic. It's for private routing, not security.

    Recommend to run GRE over a secured VPN (WireGuard / IPsec) for production.

    Consider using iptables to limit GRE access to trusted peers only.

📌 Best Practices

    Use static IP addresses or dynamic DNS.

    Keep tunnel IPs within RFC1918 private address ranges.

    Combine GRE with firewall rules for segmentation.

🐛 Troubleshooting
Issue	Solution
RTNETLINK answers: File exists	Remove existing tunnel with ip tunnel del gre1
No traffic passes	Check iptables, sysctl forwarding
Ping fails	Validate tunnel IPs and routes
🔄 Uninstall / Remove Tunnel

ip tunnel del gre1
ip addr flush dev gre1
ip link delete gre1

👨‍💻 Author

    Asphalte-Khaki
    Telegram: @Setaregan_Soren
    GitHub: asphalte-khaki
  
