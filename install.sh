
#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

LISTEN_WEB="/home/fpp/media/www/listen"

LISTEN_SYNC="/home/fpp/listen-sync"

APACHE_ROOT="/opt/fpp/www"

MUSIC_DIR="/home/fpp/media/music"

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'

info()  { printf '%b\n' "${CYAN}[INFO]${NC} $1"; }

ok()    { printf '%b\n' "${GREEN}[OK]${NC} $1"; }

fail()  { printf '%b\n' "${RED}[FAIL]${NC} $1"; exit 1; }

info "Checking prerequisites..."

[ -d "$APACHE_ROOT" ] || fail "Apache docroot $APACHE_ROOT not found. Is this an FPP system?"

[ -d "$MUSIC_DIR" ] || fail "FPP music directory $MUSIC_DIR not found."

php -v >/dev/null 2>&1 || fail "PHP is not installed."

ok "Prerequisites OK"

info "Checking hostapd and dnsmasq..."

NEED_INSTALL=""

dpkg -s hostapd >/dev/null 2>&1 || NEED_INSTALL="hostapd"

dpkg -s dnsmasq >/dev/null 2>&1 || NEED_INSTALL="$NEED_INSTALL dnsmasq"

if [ -n "$NEED_INSTALL" ]; then

  info "Installing: $NEED_INSTALL"

  sudo apt update && sudo apt install -y $NEED_INSTALL

fi

ok "hostapd and dnsmasq installed"

info "Disabling conflicting FPP configs..."

[ -f /etc/dnsmasq.d/usb.conf ] && sudo mv /etc/dnsmasq.d/usb.conf /etc/dnsmasq.d/usb.conf.disabled && ok "Disabled usb.conf"

[ -f /etc/systemd/network/usb1.network ] && sudo mv /etc/systemd/network/usb1.network /etc/systemd/network/usb1.network.disabled && ok "Disabled usb1.network"

info "Deploying web files..."

sudo mkdir -p "$LISTEN_WEB"

sudo cp "$SCRIPT_DIR/www/listen/index.html" "$LISTEN_WEB/index.html"

sudo cp "$SCRIPT_DIR/www/listen/status.php" "$LISTEN_WEB/status.php"

sudo cp "$SCRIPT_DIR/www/listen/version.php" "$LISTEN_WEB/version.php"

sudo cp "$SCRIPT_DIR/www/listen/version-debug.php" "$LISTEN_WEB/version-debug.php"

sudo cp "$SCRIPT_DIR/www/listen/detect.php" "$LISTEN_WEB/detect.php"

sudo cp "$SCRIPT_DIR/www/listen/logo.png" "$LISTEN_WEB/logo.png"

sudo cp "$SCRIPT_DIR/www/qrcode.html" "$APACHE_ROOT/qrcode.html"

sudo cp "$SCRIPT_DIR/www/print-sign.html" "$APACHE_ROOT/print-sign.html"

sudo cp "$SCRIPT_DIR/www/qrcode.min.js" "$APACHE_ROOT/qrcode.min.js"

sudo chmod -R a+rX "$LISTEN_WEB"

sudo chmod a+r "$APACHE_ROOT/qrcode.html"

sudo chmod a+r "$APACHE_ROOT/print-sign.html"

sudo chmod a+r "$APACHE_ROOT/qrcode.min.js"

ok "Web files deployed to $LISTEN_WEB"

info "Creating Apache symlinks..."

sudo rm -rf "$APACHE_ROOT/listen"

sudo ln -s "$LISTEN_WEB" "$APACHE_ROOT/listen"

info "Deploying captive portal redirect..."

sudo cp "$SCRIPT_DIR/www/.htaccess" "$APACHE_ROOT/.htaccess"

sudo chmod a+r "$APACHE_ROOT/.htaccess"

ok "Captive portal redirect configured"

info "Enabling Apache mod_rewrite and AllowOverride..."

sudo a2enmod rewrite 2>/dev/null || ok "mod_rewrite already enabled"

sudo cp "$SCRIPT_DIR/config/apache-listener.conf" /etc/apache2/conf-available/listener.conf 2>/dev/null || sudo cp "$SCRIPT_DIR/config/apache-listener.conf" /etc/httpd/conf.d/listener.conf 2>/dev/null || true

sudo a2enconf listener 2>/dev/null || true

# CRITICAL: Enable .htaccess support by setting AllowOverride All
info "Configuring Apache to allow .htaccess (required for security)..."

APACHE_CONF="/etc/apache2/sites-enabled/000-default.conf"

if [ -f "$APACHE_CONF" ]; then
  # Backup original config
  sudo cp "$APACHE_CONF" "$APACHE_CONF.listener-backup" 2>/dev/null || true

  # Change AllowOverride None to AllowOverride All in /opt/fpp/www/ directory
  sudo sed -i '/<Directory \/opt\/fpp\/www\/>/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' "$APACHE_CONF"

  ok "Apache AllowOverride enabled"
else
  warn "Apache config not found at $APACHE_CONF - you may need to manually set AllowOverride All"
fi

sudo systemctl restart apache2 2>/dev/null || sudo systemctl restart httpd 2>/dev/null || true

ok "Apache configured for captive portal"

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

info "Deploying listener-sync configs..."

sudo mkdir -p "$LISTEN_SYNC"

sudo cp "$SCRIPT_DIR/config/hostapd-listener.conf" "$LISTEN_SYNC/hostapd-listener.conf"

sudo chown -R fpp:fpp "$LISTEN_SYNC"

ok "Listener-sync configs deployed"

info "Configuring wlan1 static IP..."

# Check if wlan1 exists
if ! ip link show wlan1 >/dev/null 2>&1; then
  echo ""
  printf '%b\n' "${RED}[ERROR] wlan1 interface not found!${NC}"
  echo ""
  echo "Available network interfaces:"
  ip link show | grep -E '^[0-9]+:' | awk '{print "  - " $2}' | sed 's/:$//'
  echo ""
  echo "Troubleshooting:"
  echo "  1. Make sure USB WiFi adapter is plugged in"
  echo "  2. Run 'lsusb' to verify adapter is detected"
  echo "  3. Run 'dmesg | tail -20' to check for driver errors"
  echo "  4. Some adapters may appear as wlan0, wlan2, etc."
  echo ""
  echo "If your USB WiFi has a different name, you'll need to:"
  echo "  - Update config files to use the correct interface name"
  echo "  - Or create a udev rule to rename it to wlan1"
  echo ""
  fail "Cannot continue without wlan1 interface"
fi

# Configure wlan1 using ip commands instead of systemd-networkd
# This avoids conflicts with FPP's existing network management
sudo ip addr flush dev wlan1 2>/dev/null || true
sudo ip addr add 192.168.50.1/24 dev wlan1 2>/dev/null || true
sudo ip link set wlan1 up 2>/dev/null || true

# Create startup script to configure wlan1 on boot
cat > /tmp/wlan1-setup.sh << 'EOF'
#!/bin/bash
# Wait for wlan1 to exist
for i in {1..10}; do
  if ip link show wlan1 &>/dev/null; then
    break
  fi
  sleep 1
done

# Configure wlan1 IP
ip addr flush dev wlan1 2>/dev/null || true
ip addr add 192.168.50.1/24 dev wlan1 2>/dev/null || true
ip link set wlan1 up 2>/dev/null || true
EOF

sudo mv /tmp/wlan1-setup.sh /usr/local/bin/wlan1-setup.sh
sudo chmod +x /usr/local/bin/wlan1-setup.sh

# Create systemd service to run wlan1-setup on boot
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

ok "wlan1 configured as 192.168.50.1"

info "Configuring dnsmasq..."

# Backup original dnsmasq.conf if it exists and hasn't been backed up
if [ -f /etc/dnsmasq.conf ] && [ ! -f /etc/dnsmasq.conf.listener-backup ]; then
  sudo cp /etc/dnsmasq.conf /etc/dnsmasq.conf.listener-backup
  info "Backed up original dnsmasq.conf"
fi

sudo cp "$SCRIPT_DIR/config/dnsmasq.conf" /etc/dnsmasq.conf

sudo mkdir -p /etc/systemd/system/dnsmasq.service.d

sudo cp "$SCRIPT_DIR/config/dnsmasq-override.conf" /etc/systemd/system/dnsmasq.service.d/override.conf

sudo systemctl daemon-reload

# Stop dnsmasq first to avoid conflicts
info "Restarting dnsmasq..."
sudo systemctl stop dnsmasq 2>/dev/null || true
sudo pkill -9 dnsmasq 2>/dev/null || true
sleep 2

sudo systemctl enable dnsmasq
sudo systemctl start dnsmasq 2>/dev/null || warn "dnsmasq may need manual start - check 'systemctl status dnsmasq'"

# Verify dnsmasq started
sleep 2
if systemctl is-active --quiet dnsmasq; then
  ok "dnsmasq running (DHCP on wlan1)"
else
  warn "dnsmasq may not be running - check 'systemctl status dnsmasq'"
fi

info "Configuring listener AP service..."

sudo systemctl stop hostapd 2>/dev/null || true

sudo systemctl disable hostapd 2>/dev/null || true

sudo cp "$SCRIPT_DIR/config/listener-ap.service" /etc/systemd/system/listener-ap.service

sudo systemctl daemon-reload

sudo systemctl enable listener-ap

sudo systemctl start listener-ap

ok "listener-ap running (SSID: SHOW_AUDIO)"

info "Disabling IP forwarding..."

sudo sysctl -w net.ipv4.ip_forward=0 >/dev/null

echo "net.ipv4.ip_forward=0" | sudo tee /etc/sysctl.d/99-no-forward.conf >/dev/null

if command -v iptables >/dev/null 2>&1; then
  # Prevent forwarding from/to wlan1 (blocks internet access)
  sudo iptables -C FORWARD -i wlan1 -j DROP 2>/dev/null || sudo iptables -A FORWARD -i wlan1 -j DROP
  sudo iptables -C FORWARD -o wlan1 -j DROP 2>/dev/null || sudo iptables -A FORWARD -o wlan1 -j DROP

  # Device isolation - prevent visitors from accessing each other
  # Block traffic between clients (192.168.50.10-250) but allow traffic to server (192.168.50.1)
  sudo iptables -C INPUT -i wlan1 -m iprange --src-range 192.168.50.10-192.168.50.250 -d 192.168.50.1 -j ACCEPT 2>/dev/null || \
    sudo iptables -I INPUT -i wlan1 -m iprange --src-range 192.168.50.10-192.168.50.250 -d 192.168.50.1 -j ACCEPT

  sudo iptables -C INPUT -i wlan1 -s 192.168.50.0/24 -j DROP 2>/dev/null || \
    sudo iptables -A INPUT -i wlan1 -s 192.168.50.0/24 -j DROP
fi

ok "IP forwarding disabled, devices isolated"

echo ""

echo "========================================="

printf '%b\n' "${GREEN}  FPP Listener Sync installed!${NC}"

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

systemctl is-active --quiet listener-ap && ok "listener-ap: running" || { printf '%b\n' "${RED}[FAIL] listener-ap${NC}"; ERRORS=$((ERRORS+1)); }

systemctl is-active --quiet dnsmasq && ok "dnsmasq: running" || { printf '%b\n' "${RED}[FAIL] dnsmasq${NC}"; ERRORS=$((ERRORS+1)); }

IP=$(ip addr show wlan1 2>/dev/null | grep 'inet ' | awk '{print $2}')

[ "$IP" = "192.168.50.1/24" ] && ok "wlan1: 192.168.50.1/24" || { printf '%b\n' "${RED}[FAIL] wlan1 IP: $IP${NC}"; ERRORS=$((ERRORS+1)); }

HTTP=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1/listen/ 2>/dev/null)

[ "$HTTP" = "200" ] && ok "/listen/: HTTP 200" || { printf '%b\n' "${RED}[FAIL] /listen/: HTTP $HTTP${NC}"; ERRORS=$((ERRORS+1)); }

HTTP2=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1/listen/status.php 2>/dev/null)

[ "$HTTP2" = "200" ] && ok "status.php: HTTP 200" || { printf '%b\n' "${RED}[FAIL] status.php: HTTP $HTTP2${NC}"; ERRORS=$((ERRORS+1)); }

echo ""

[ $ERRORS -eq 0 ] && printf '%b\n' "${GREEN}All checks passed. Ready to go!${NC}" || printf '%b\n' "${RED}$ERRORS check(s) failed.${NC}"

