
#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

LISTEN_WEB="/home/fpp/media/www/listen"

LISTEN_SYNC="/home/fpp/listen-sync"

APACHE_ROOT="/opt/fpp/www"

MUSIC_DIR="/home/fpp/media/music"

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC} $1"; }

ok()    { echo -e "${GREEN}[OK]${NC} $1"; }

fail()  { echo -e "${RED}[FAIL]${NC} $1"; exit 1; }

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

sudo cp "$SCRIPT_DIR/www/listen/logo.png" "$LISTEN_WEB/logo.png"

sudo chmod -R a+rX "$LISTEN_WEB"

ok "Web files deployed to $LISTEN_WEB"

info "Creating Apache symlinks..."

sudo rm -rf "$APACHE_ROOT/listen"

sudo ln -s "$LISTEN_WEB" "$APACHE_ROOT/listen"

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

sudo cp "$SCRIPT_DIR/config/20-listener-ap.network" /etc/systemd/network/20-listener-ap.network

sudo systemctl enable systemd-networkd

sudo systemctl restart systemd-networkd

ok "wlan1 configured as 192.168.50.1"

info "Configuring dnsmasq..."

sudo cp "$SCRIPT_DIR/config/dnsmasq.conf" /etc/dnsmasq.conf

sudo mkdir -p /etc/systemd/system/dnsmasq.service.d

sudo cp "$SCRIPT_DIR/config/dnsmasq-override.conf" /etc/systemd/system/dnsmasq.service.d/override.conf

sudo systemctl daemon-reload

sudo systemctl enable dnsmasq

sudo systemctl restart dnsmasq

ok "dnsmasq running (DHCP on wlan1)"

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

sudo iptables -C FORWARD -i wlan1 -j DROP 2>/dev/null || sudo iptables -A FORWARD -i wlan1 -j DROP

sudo iptables -C FORWARD -o wlan1 -j DROP 2>/dev/null || sudo iptables -A FORWARD -o wlan1 -j DROP

ok "IP forwarding disabled, networks isolated"

echo ""

echo "========================================="

echo -e "${GREEN}  FPP Listener Sync installed!${NC}"

echo "========================================="

echo "  SSID:     SHOW_AUDIO (open)"

echo "  Page:     http://192.168.50.1/listen/"

echo "  DNS:      http://listen.local/listen/"

echo "========================================="

info "Running self-test..."

ERRORS=0

systemctl is-active --quiet listener-ap && ok "listener-ap: running" || { echo -e "${RED}[FAIL] listener-ap${NC}"; ERRORS=$((ERRORS+1)); }

systemctl is-active --quiet dnsmasq && ok "dnsmasq: running" || { echo -e "${RED}[FAIL] dnsmasq${NC}"; ERRORS=$((ERRORS+1)); }

IP=$(ip addr show wlan1 2>/dev/null | grep 'inet ' | awk '{print $2}')

[ "$IP" = "192.168.50.1/24" ] && ok "wlan1: 192.168.50.1/24" || { echo -e "${RED}[FAIL] wlan1 IP: $IP${NC}"; ERRORS=$((ERRORS+1)); }

HTTP=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1/listen/ 2>/dev/null)

[ "$HTTP" = "200" ] && ok "/listen/: HTTP 200" || { echo -e "${RED}[FAIL] /listen/: HTTP $HTTP${NC}"; ERRORS=$((ERRORS+1)); }

HTTP2=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1/listen/status.php 2>/dev/null)

[ "$HTTP2" = "200" ] && ok "status.php: HTTP 200" || { echo -e "${RED}[FAIL] status.php: HTTP $HTTP2${NC}"; ERRORS=$((ERRORS+1)); }

echo ""

[ $ERRORS -eq 0 ] && echo -e "${GREEN}All checks passed. Ready to go!${NC}" || echo -e "${RED}$ERRORS check(s) failed.${NC}"

