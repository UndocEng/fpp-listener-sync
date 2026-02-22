#!/bin/bash
# =============================================================================
# fpp_install.sh — FPP Phone Listener Plugin Install Script
# =============================================================================
# Called by FPP's plugin manager after cloning, or manually via:
#   sudo ./scripts/fpp_install.sh
#
# This is the main install logic. install.sh at repo root is a thin wrapper.
# =============================================================================

set -e

# Determine plugin directory (this script lives in scripts/)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

LISTEN_WEB="/home/fpp/media/www/listen"
LISTEN_SYNC="/home/fpp/listen-sync"
APACHE_ROOT="/opt/fpp/www"
MUSIC_DIR="/home/fpp/media/music"

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { printf '%b\n' "${CYAN}[INFO]${NC} $1"; }
ok()    { printf '%b\n' "${GREEN}[OK]${NC} $1"; }
warn()  { printf '%b\n' "${YELLOW}[WARN]${NC} $1"; }
fail()  { printf '%b\n' "${RED}[FAIL]${NC} $1"; exit 1; }

VERSION=$(cat "$PLUGIN_DIR/VERSION" 2>/dev/null || echo "unknown")
echo ""
info "FPP Phone Listener - v${VERSION}"
echo ""

# Fix Windows line endings on all deployed files
if command -v sed >/dev/null 2>&1; then
  find "$PLUGIN_DIR" \( -name "*.sh" -o -name "*.py" -o -name "*.service" \
    -o -name "*.conf" -o -name "*.html" -o -name "*.php" -o -name "*.htaccess" \
    -o -name "*.inc" -o -name "*.json" -o -name "*.js" -o -name "*.css" \) \
    -exec sed -i 's/\r$//' {} + 2>/dev/null || true
fi

# --- Step 1: Prerequisites ---
info "Checking prerequisites..."
[ -d "$APACHE_ROOT" ] || fail "Apache docroot $APACHE_ROOT not found. Is this an FPP system?"
[ -d "$MUSIC_DIR" ] || fail "FPP music directory $MUSIC_DIR not found."
php -v >/dev/null 2>&1 || fail "PHP is not installed."
python3 --version >/dev/null 2>&1 || fail "Python3 is not installed."
ok "Prerequisites OK"

# --- Step 2: Python websockets ---
info "Checking Python websockets package..."
if ! python3 -c "import websockets" 2>/dev/null; then
  info "Installing websockets package..."
  sudo apt install -y python3-websockets 2>/dev/null || \
    python3 -m pip install websockets 2>/dev/null || \
    sudo python3 -m pip install websockets --break-system-packages 2>/dev/null || \
    fail "Could not install Python websockets package"
fi
ok "Python websockets package available"

# --- Step 3: hostapd + dnsmasq ---
info "Checking hostapd and dnsmasq..."
NEED_INSTALL=""
dpkg -s hostapd >/dev/null 2>&1 || NEED_INSTALL="hostapd"
dpkg -s dnsmasq >/dev/null 2>&1 || NEED_INSTALL="$NEED_INSTALL dnsmasq"
if [ -n "$NEED_INSTALL" ]; then
  info "Installing: $NEED_INSTALL"
  sudo apt update && sudo apt install -y $NEED_INSTALL
fi
ok "hostapd and dnsmasq installed"

# --- Step 4: Disable conflicting FPP configs ---
info "Disabling conflicting FPP configs..."
[ -f /etc/dnsmasq.d/usb.conf ] && sudo mv /etc/dnsmasq.d/usb.conf /etc/dnsmasq.d/usb.conf.disabled && ok "Disabled usb.conf"
[ -f /etc/systemd/network/usb1.network ] && sudo mv /etc/systemd/network/usb1.network /etc/systemd/network/usb1.network.disabled && ok "Disabled usb1.network"

# --- Step 5: Deploy web files ---
info "Deploying web files..."
sudo mkdir -p "$LISTEN_WEB"
sudo cp "$PLUGIN_DIR/www/listen/index.html" "$LISTEN_WEB/index.html"
sudo cp "$PLUGIN_DIR/www/listen/status.php" "$LISTEN_WEB/status.php"
sudo cp "$PLUGIN_DIR/www/listen/version.php" "$LISTEN_WEB/version.php"
sudo cp "$PLUGIN_DIR/www/listen/version-debug.php" "$LISTEN_WEB/version-debug.php"
sudo cp "$PLUGIN_DIR/www/listen/detect.php" "$LISTEN_WEB/detect.php"
sudo cp "$PLUGIN_DIR/www/listen/portal-api.php" "$LISTEN_WEB/portal-api.php"
sudo cp "$PLUGIN_DIR/www/listen/logo_cyan.png" "$LISTEN_WEB/logo_cyan.png"
sudo cp "$PLUGIN_DIR/www/listen/logo_amber.png" "$LISTEN_WEB/logo_amber.png"
sudo cp "$PLUGIN_DIR/www/listen/dashboard.js" "$LISTEN_WEB/dashboard.js"
sudo cp "$PLUGIN_DIR/www/listen/dashboard.css" "$LISTEN_WEB/dashboard.css"
sudo cp "$PLUGIN_DIR/VERSION" "$LISTEN_WEB/VERSION"
# Also update plugin directory so FPP's plugin.php handler reads correct version
FPP_PLUGIN_DIR="/home/fpp/media/plugins/fpp-listener-sync"
if [ -d "$FPP_PLUGIN_DIR" ]; then
    sudo cp "$PLUGIN_DIR/VERSION" "$FPP_PLUGIN_DIR/VERSION"
    sudo cp "$PLUGIN_DIR/plugin.php" "$FPP_PLUGIN_DIR/plugin.php"
    sudo cp "$PLUGIN_DIR/listener-api.php" "$FPP_PLUGIN_DIR/listener-api.php"
    sudo cp "$PLUGIN_DIR/README.md" "$FPP_PLUGIN_DIR/README.md"
fi
sudo cp "$PLUGIN_DIR/www/qrcode.html" "$APACHE_ROOT/qrcode.html"
sudo cp "$PLUGIN_DIR/www/print-sign.html" "$APACHE_ROOT/print-sign.html"
sudo cp "$PLUGIN_DIR/www/qrcode.min.js" "$APACHE_ROOT/qrcode.min.js"
sudo chmod -R a+rX "$LISTEN_WEB"
sudo chmod a+r "$APACHE_ROOT/qrcode.html" "$APACHE_ROOT/print-sign.html" "$APACHE_ROOT/qrcode.min.js"
ok "Web files deployed to $LISTEN_WEB"

# --- Step 6: Apache symlinks ---
info "Creating Apache symlinks..."
sudo rm -rf "$APACHE_ROOT/listen"
sudo ln -s "$LISTEN_WEB" "$APACHE_ROOT/listen"

# --- Step 7: Captive portal .htaccess ---
info "Deploying captive portal redirect..."
sudo cp "$PLUGIN_DIR/www/.htaccess" "$APACHE_ROOT/.htaccess"
sudo chmod a+r "$APACHE_ROOT/.htaccess"
ok "Captive portal redirect configured"

# --- Step 8: Apache modules + config ---
info "Enabling Apache modules..."
sudo a2enmod rewrite 2>/dev/null || ok "mod_rewrite already enabled"
sudo a2enmod proxy 2>/dev/null || ok "mod_proxy already enabled"
sudo a2enmod proxy_wstunnel 2>/dev/null || ok "mod_proxy_wstunnel already enabled"
sudo a2enmod headers 2>/dev/null || ok "mod_headers already enabled"
sudo cp "$PLUGIN_DIR/config/apache-listener.conf" /etc/apache2/conf-available/listener.conf 2>/dev/null || true
sudo a2enconf listener 2>/dev/null || true

info "Configuring Apache to allow .htaccess..."
APACHE_CONF="/etc/apache2/sites-enabled/000-default.conf"
if [ -f "$APACHE_CONF" ]; then
  sudo cp "$APACHE_CONF" "$APACHE_CONF.listener-backup" 2>/dev/null || true
  sudo sed -i '/<Directory \/opt\/fpp\/www\/>/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' "$APACHE_CONF"
  ok "Apache AllowOverride enabled"
fi

sudo a2dissite listener-ssl 2>/dev/null || true
sudo a2dismod ssl 2>/dev/null || true
sudo systemctl restart apache2 2>/dev/null || sudo systemctl restart httpd 2>/dev/null || true
ok "Apache configured"

# --- Step 8b: Replace FPP network config page with plugin redirect ---
info "Redirecting network config page to plugin dashboard..."
NETCONFIG="$APACHE_ROOT/networkconfig.php"
if [ -f "$NETCONFIG" ] && [ ! -f "$NETCONFIG.listener-backup" ]; then
  sudo cp "$NETCONFIG" "$NETCONFIG.listener-backup"
  info "Backed up original networkconfig.php"
fi
sudo tee "$NETCONFIG" > /dev/null <<'PHPREDIRECT'
<?php
header('Location: plugin.php?plugin=fpp-listener-sync&page=plugin.php');
exit;
PHPREDIRECT
ok "Network page redirects to plugin dashboard"

# Also copy the original as a directly-accessible page (for "Advanced" button)
if [ -f "$NETCONFIG.listener-backup" ]; then
  sudo cp "$NETCONFIG.listener-backup" "$APACHE_ROOT/networkconfig-original.php"
  ok "Original network page available at /networkconfig-original.php"
fi

# Music symlink
if [ ! -L "$APACHE_ROOT/music" ] && [ ! -d "$APACHE_ROOT/music" ]; then
  sudo ln -s "$MUSIC_DIR" "$APACHE_ROOT/music"
elif [ -L "$APACHE_ROOT/music" ]; then
  CURRENT=$(readlink -f "$APACHE_ROOT/music")
  if [ "$CURRENT" != "$MUSIC_DIR" ]; then
    sudo rm -f "$APACHE_ROOT/music"
    sudo ln -s "$MUSIC_DIR" "$APACHE_ROOT/music"
  fi
fi
sudo chmod -R a+rX "$MUSIC_DIR"
ok "Apache symlinks created"

# --- Step 9: Deploy runtime configs + WebSocket sync server ---
info "Deploying listener-sync configs..."
sudo mkdir -p "$LISTEN_SYNC"
sudo cp "$PLUGIN_DIR/config/hostapd-listener.conf" "$LISTEN_SYNC/hostapd-listener.conf"
sudo cp "$PLUGIN_DIR/server/ws-sync-server.py" "$LISTEN_SYNC/ws-sync-server.py"
sudo chown -R fpp:fpp "$LISTEN_SYNC"
ok "Listener-sync configs deployed"

# ws-sync systemd service
info "Installing WebSocket sync beacon service..."
sudo cp "$PLUGIN_DIR/config/ws-sync.service" /etc/systemd/system/ws-sync.service
sudo systemctl daemon-reload
sudo systemctl enable ws-sync
sudo systemctl restart ws-sync
ok "ws-sync service installed and started"

# --- Step 10: Configure wlan1 static IP ---
info "Configuring wlan1 static IP..."
if ! ip link show wlan1 >/dev/null 2>&1; then
  echo ""
  printf '%b\n' "${YELLOW}[WARN] wlan1 interface not found — USB WiFi adapter may not be plugged in${NC}"
  echo "  The AP will start once a USB WiFi adapter is connected."
  echo "  Available interfaces: $(ip link show | grep -oP '^\d+:\s+\K[^:@]+' | tr '\n' ' ')"
  echo ""
else
  sudo mkdir -p /etc/systemd/network
  sudo cp "$PLUGIN_DIR/config/20-listener-ap.network" /etc/systemd/network/20-listener-ap.network
  sudo ip addr flush dev wlan1 2>/dev/null || true
  sudo ip addr add 192.168.50.1/24 dev wlan1 2>/dev/null || true
  sudo ip link set wlan1 up 2>/dev/null || true
  ok "wlan1 configured as 192.168.50.1"
fi

# wlan1-setup boot service
cat > /tmp/wlan1-setup.sh << 'EOF'
#!/bin/bash
for i in {1..10}; do
  ip link show wlan1 &>/dev/null && break
  sleep 1
done
ip addr flush dev wlan1 2>/dev/null || true
ip addr add 192.168.50.1/24 dev wlan1 2>/dev/null || true
ip link set wlan1 up 2>/dev/null || true
EOF
sudo mv /tmp/wlan1-setup.sh /usr/local/bin/wlan1-setup.sh
sudo chmod +x /usr/local/bin/wlan1-setup.sh

cat > /tmp/wlan1-setup.service << 'EOF'
[Unit]
Description=Configure wlan1 for FPP Listener
After=network.target
Before=listener-ap.service dnsmasq.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/wlan1-setup.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
sudo mv /tmp/wlan1-setup.service /etc/systemd/system/wlan1-setup.service
sudo systemctl daemon-reload
sudo systemctl enable wlan1-setup.service

# --- Step 11: Configure dnsmasq ---
info "Configuring dnsmasq..."
if [ -f /etc/dnsmasq.conf ] && [ ! -f /etc/dnsmasq.conf.listener-backup ]; then
  sudo cp /etc/dnsmasq.conf /etc/dnsmasq.conf.listener-backup
  info "Backed up original dnsmasq.conf"
fi
sudo cp "$PLUGIN_DIR/config/dnsmasq.conf" /etc/dnsmasq.conf
sudo mkdir -p /etc/systemd/system/dnsmasq.service.d
sudo cp "$PLUGIN_DIR/config/dnsmasq-override.conf" /etc/systemd/system/dnsmasq.service.d/override.conf
sudo systemctl daemon-reload
info "Restarting dnsmasq..."
sudo systemctl stop dnsmasq 2>/dev/null || true
sudo pkill -9 dnsmasq 2>/dev/null || true
sleep 2
sudo systemctl enable dnsmasq
sudo systemctl start dnsmasq 2>/dev/null || warn "dnsmasq may need manual start"
sleep 2
systemctl is-active --quiet dnsmasq && ok "dnsmasq running" || warn "dnsmasq may not be running"

# --- Step 12: Start hostapd ---
info "Configuring listener AP service..."
sudo systemctl stop hostapd 2>/dev/null || true
sudo systemctl disable hostapd 2>/dev/null || true
sudo cp "$PLUGIN_DIR/config/listener-ap.service" /etc/systemd/system/listener-ap.service
sudo systemctl daemon-reload
sudo systemctl enable listener-ap
sudo systemctl start listener-ap
ok "listener-ap running (SSID: SHOW_AUDIO)"

# --- Step 13: Network security ---
info "Disabling IP forwarding..."
sudo sysctl -w net.ipv4.ip_forward=0 >/dev/null
echo "net.ipv4.ip_forward=0" | sudo tee /etc/sysctl.d/99-no-forward.conf >/dev/null

NFT="/usr/sbin/nft"
if [ -x "$NFT" ]; then
  sudo $NFT delete table inet listener_filter 2>/dev/null || true
  sudo $NFT add table inet listener_filter
  sudo $NFT add chain inet listener_filter wlan1_input '{ type filter hook input priority 0; policy accept; }'
  sudo $NFT add rule inet listener_filter wlan1_input iifname wlan1 udp dport '{67, 68}' accept
  sudo $NFT add rule inet listener_filter wlan1_input iifname wlan1 ip daddr 192.168.50.1 udp dport 53 accept
  sudo $NFT add rule inet listener_filter wlan1_input iifname wlan1 ip daddr 192.168.50.1 tcp dport 53 accept
  sudo $NFT add rule inet listener_filter wlan1_input iifname wlan1 ip daddr 192.168.50.1 tcp dport '{80, 8080}' accept
  sudo $NFT add rule inet listener_filter wlan1_input iifname wlan1 meta l4proto tcp reject with tcp reset
  sudo $NFT add rule inet listener_filter wlan1_input iifname wlan1 reject
  ok "nftables firewall active"
else
  printf '%b\n' "${RED}[WARN] nftables not found — wlan1 traffic not firewalled!${NC}"
fi
ok "IP forwarding disabled, devices isolated"

# --- Step 14: Sudoers for admin API ---
info "Configuring sudoers for admin UI..."
SUDOERS_FILE="/etc/sudoers.d/fpp-listener"
sudo tee "$SUDOERS_FILE" > /dev/null <<'SUDOERS'
# FPP Phone Listener plugin — allow www-data to manage AP services
www-data ALL=(ALL) NOPASSWD: /usr/bin/tee /home/fpp/listen-sync/hostapd-listener.conf
www-data ALL=(ALL) NOPASSWD: /usr/bin/tee /etc/dnsmasq.conf
www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart listener-ap.service
www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart dnsmasq
www-data ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart ws-sync
www-data ALL=(ALL) NOPASSWD: /usr/sbin/iw dev * station dump
www-data ALL=(ALL) NOPASSWD: /usr/sbin/nft *
www-data ALL=(ALL) NOPASSWD: /sbin/ip addr *
www-data ALL=(ALL) NOPASSWD: /sbin/ip link *
www-data ALL=(ALL) NOPASSWD: /usr/bin/sed -i *
www-data ALL=(ALL) NOPASSWD: /usr/sbin/wpa_cli *
www-data ALL=(ALL) NOPASSWD: /usr/bin/tee /home/fpp/listen-sync/roles.json
www-data ALL=(ALL) NOPASSWD: /usr/bin/journalctl --rotate
www-data ALL=(ALL) NOPASSWD: /usr/bin/journalctl --vacuum-time=1s *
SUDOERS
sudo chmod 440 "$SUDOERS_FILE"
if sudo visudo -cf "$SUDOERS_FILE" >/dev/null 2>&1; then
  ok "Sudoers configured"
else
  warn "Sudoers syntax check failed — admin API may not work"
fi

# --- Step 15: Self-Test ---
echo ""
echo "========================================="
printf '%b\n' "${GREEN}  FPP Phone Listener installed!${NC}"
echo "========================================="
echo "  SSID:     SHOW_AUDIO (open)"
echo "  Page:     http://192.168.50.1/listen/"
echo "  DNS:      http://listen.local/listen/"
echo ""
echo "  QR Code:  http://192.168.50.1/qrcode.html"
echo "  Print:    http://192.168.50.1/print-sign.html"
echo "========================================="

info "Running self-test..."
ERRORS=0
if ip link show wlan1 >/dev/null 2>&1; then
  systemctl is-active --quiet listener-ap && ok "listener-ap: running" || { printf '%b\n' "${RED}[FAIL] listener-ap${NC}"; ERRORS=$((ERRORS+1)); }
fi
systemctl is-active --quiet dnsmasq && ok "dnsmasq: running" || { printf '%b\n' "${RED}[FAIL] dnsmasq${NC}"; ERRORS=$((ERRORS+1)); }

if ip link show wlan1 >/dev/null 2>&1; then
  IP=$(ip addr show wlan1 2>/dev/null | grep 'inet ' | awk '{print $2}')
  [ "$IP" = "192.168.50.1/24" ] && ok "wlan1: 192.168.50.1/24" || { printf '%b\n' "${RED}[FAIL] wlan1 IP: $IP${NC}"; ERRORS=$((ERRORS+1)); }
fi

systemctl is-active --quiet ws-sync && ok "ws-sync: running" || { printf '%b\n' "${RED}[FAIL] ws-sync${NC}"; ERRORS=$((ERRORS+1)); }

if [ -x /usr/sbin/nft ]; then
  /usr/sbin/nft list table inet listener_filter >/dev/null 2>&1 && ok "nftables: active" || { printf '%b\n' "${RED}[FAIL] nftables${NC}"; ERRORS=$((ERRORS+1)); }
fi

WS_HTTP=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8080/ 2>/dev/null)
[ "$WS_HTTP" = "426" ] && ok "ws-sync port 8080: responding" || { printf '%b\n' "${RED}[FAIL] ws-sync port 8080: HTTP $WS_HTTP${NC}"; ERRORS=$((ERRORS+1)); }

HTTP=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1/listen/ 2>/dev/null)
[ "$HTTP" = "200" ] && ok "/listen/: HTTP 200" || { printf '%b\n' "${RED}[FAIL] /listen/: HTTP $HTTP${NC}"; ERRORS=$((ERRORS+1)); }

HTTP2=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1/listen/status.php 2>/dev/null)
[ "$HTTP2" = "200" ] && ok "status.php: HTTP 200" || { printf '%b\n' "${RED}[FAIL] status.php: HTTP $HTTP2${NC}"; ERRORS=$((ERRORS+1)); }

echo ""
if [ $ERRORS -eq 0 ]; then
  echo "========================================="
  printf '%b\n' "${GREEN}  Install successful! Running v${VERSION}${NC}"
  echo "========================================="
else
  echo "========================================="
  printf '%b\n' "${RED}  Install completed with $ERRORS error(s). Running v${VERSION}${NC}"
  echo "========================================="
fi
