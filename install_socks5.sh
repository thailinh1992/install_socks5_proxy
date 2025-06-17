#!/usr/bin/env bash
# SOCKS5 (Dante) auto installer - Fixed credentials and port

set -e

draw_box() {
    local title="$1"
    local content="$2"
    local width=60
    local GREEN='\033[0;32m'
    local BLUE='\033[0;34m'
    local YELLOW='\033[1;33m'
    local NC='\033[0m'
    local BOLD='\033[1m'

    echo ""
    echo -e "${GREEN}┌$(printf '─%.0s' $(seq 1 $((width-2))))┐${NC}"
    echo -e "${GREEN}│${BOLD}${YELLOW} $(printf "%-*s" $((width-4)) "$title") ${NC}${GREEN}│${NC}"
    echo -e "${GREEN}├$(printf '─%.0s' $(seq 1 $((width-2))))┤${NC}"
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            echo -e "${GREEN}│${NC} $(printf "%-*s" $((width-4)) "$line") ${GREEN}│${NC}"
        fi
    done <<< "$content"
    echo -e "${GREEN}└$(printf '─%.0s' $(seq 1 $((width-2))))┘${NC}"
    echo ""
}

# Detect OS
OS=""
if [ -f /etc/os-release ]; then
    . /etc/os-release
    case "$ID" in
        ubuntu|debian) OS="debian" ;;
        amzn|centos|rhel|rocky|almalinux) OS="redhat" ;;
        *) echo "❌ Unsupported OS: $ID"; exit 1 ;;
    esac
else
    echo "❌ Cannot detect OS."; exit 1
fi

EXT_IF=$(ip route | awk '/default/ {print $5; exit}')
EXT_IF=${EXT_IF:-eth0}
PUBLIC_IP=$(curl -4 -s https://api.ipify.org)

install_socks5() {
    local USERNAME="linh"
    local PASSWORD="linh123@"
    local PORT="1219"

    if [ "$OS" = "debian" ]; then
        apt-get update >/dev/null 2>&1
        DEBIAN_FRONTEND=noninteractive apt-get install -y dante-server curl iptables iptables-persistent >/dev/null 2>&1
    else
        yum install -y epel-release >/dev/null 2>&1
        yum install -y dante-server curl iptables-services >/dev/null 2>&1
        systemctl enable iptables >/dev/null 2>&1
        systemctl start iptables >/dev/null 2>&1
    fi

    useradd -M -N -s /usr/sbin/nologin "$USERNAME" >/dev/null 2>&1 || true
    echo "${USERNAME}:${PASSWORD}" | chpasswd >/dev/null 2>&1

    [ -f /etc/danted.conf ] && cp /etc/danted.conf /etc/danted.conf.bak.$(date +%F_%T) >/dev/null 2>&1
    cat > /etc/danted.conf <<EOF
logoutput: syslog /var/log/danted.log

internal: 0.0.0.0 port = ${PORT}
external: ${EXT_IF}

method: pam
user.privileged: root
user.notprivileged: nobody

client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect error
}

socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    command: bind connect udpassociate
    log: connect disconnect error
}
EOF

    chmod 644 /etc/danted.conf
    systemctl restart danted >/dev/null 2>&1
    systemctl enable danted >/dev/null 2>&1

    if command -v ufw >/dev/null 2>&1; then
        ufw allow "${PORT}/tcp" >/dev/null 2>&1
    else
        iptables -I INPUT -p tcp --dport "${PORT}" -j ACCEPT >/dev/null 2>&1
        iptables-save > /etc/iptables/rules.v4 >/dev/null 2>&1 || true
    fi

    echo "socks5://${PUBLIC_IP}:${PORT}:${USERNAME}:${PASSWORD}"
}

echo "🚀 Installing SOCKS5 server with fixed configuration..."
socks_info=$(install_socks5)
draw_box "🧦 SOCKS5 PROXY SERVER" "$socks_info"
