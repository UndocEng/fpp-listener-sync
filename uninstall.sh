
#!/bin/bash

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'

info()  { printf '%b\n' "${CYAN}[INFO]${NC} $1"; }

ok()    { printf '%b\n' "${GREEN}[OK]${NC} $1"; }

warn()  { printf '%b\n' "${YELLOW}[WARN]${NC} $1"; }

echo ""

echo "This will remove FPP Listener Sync and restore defaults."

read -p "Continue? (y/N) " -n 1 -r

echo ""

[[ ! $REPLY =~ ^[Yy]$ ]] && echo "Cancelled." && exit 0

info "Stopping services..."

sudo systemctl stop ws-sync 2>/dev/null || true
sudo systemctl disable ws-sync 2>/dev/null || true
sudo rm -f /etc/systemd/system/ws-sync.service

sudo systemctl stop listener-ap 2>/dev/null || true
sudo systemctl disable listener-ap 2>/dev/null || true
sudo rm -f /etc/systemd/system/listener-ap.service

sudo systemctl stop wlan1-setup 2>/dev/null || true
sudo systemctl disable wlan1-setup.service 2>/dev/null || true
sudo rm -f /etc/systemd/system/wlan1-setup.service
sudo rm -f /usr/local/bin/wlan1-setup.sh

sudo systemctl stop dnsmasq 2>/dev/null || true
sudo rm -rf /etc/systemd/system/dnsmasq.service.d

info "Removing iptables rules..."

if command -v iptables >/dev/null 2>&1; then
  sudo iptables -D FORWARD -i wlan1 -j DROP 2>/dev/null || true
  sudo iptables -D FORWARD -o wlan1 -j DROP 2>/dev/null || true
  sudo iptables -D INPUT -i wlan1 -m iprange --src-range 192.168.50.10-192.168.50.250 -d 192.168.50.1 -j ACCEPT 2>/dev/null || true
  sudo iptables -D INPUT -i wlan1 -s 192.168.50.0/24 -j DROP 2>/dev/null || true
  ok "iptables rules removed"
fi

info "Removing configs..."

sudo rm -f /etc/systemd/network/20-listener-ap.network
sudo rm -f /etc/sysctl.d/99-no-forward.conf

info "Restoring FPP configs..."

[ -f /etc/dnsmasq.d/usb.conf.disabled ] && sudo mv /etc/dnsmasq.d/usb.conf.disabled /etc/dnsmasq.d/usb.conf && ok "Restored usb.conf"

[ -f /etc/systemd/network/usb1.network.disabled ] && sudo mv /etc/systemd/network/usb1.network.disabled /etc/systemd/network/usb1.network && ok "Restored usb1.network"

# Restore dnsmasq.conf from backup
if [ -f /etc/dnsmasq.conf.listener-backup ]; then
  sudo mv /etc/dnsmasq.conf.listener-backup /etc/dnsmasq.conf
  ok "Restored original dnsmasq.conf"
else
  warn "No dnsmasq.conf backup found - original config not restored"
fi

sudo systemctl restart dnsmasq 2>/dev/null || true

info "Restoring Apache config..."

# Restore Apache AllowOverride setting from backup
if [ -f /etc/apache2/sites-enabled/000-default.conf.listener-backup ]; then
  sudo mv /etc/apache2/sites-enabled/000-default.conf.listener-backup /etc/apache2/sites-enabled/000-default.conf
  ok "Restored Apache config"
else
  warn "No Apache config backup found - you may need to manually restore AllowOverride"
fi

# Remove Apache listener config
sudo rm -f /etc/apache2/conf-available/listener.conf
sudo rm -f /etc/apache2/conf-enabled/listener.conf
sudo a2disconf listener 2>/dev/null || true

info "Removing web files..."

sudo rm -rf /opt/fpp/www/listen
sudo rm -f /opt/fpp/www/music
sudo rm -f /opt/fpp/www/.htaccess
sudo rm -f /opt/fpp/www/qrcode.html
sudo rm -f /opt/fpp/www/print-sign.html
sudo rm -f /opt/fpp/www/qrcode.min.js

sudo rm -rf /home/fpp/media/www/listen
sudo rm -rf /home/fpp/listen-sync

info "Restarting Apache..."

sudo systemctl restart apache2 2>/dev/null || sudo systemctl restart httpd 2>/dev/null || true

info "Reloading systemd..."

sudo systemctl daemon-reload

info "Bringing down wlan1..."

sudo ip link set wlan1 down 2>/dev/null || true
sudo ip addr flush dev wlan1 2>/dev/null || true

echo ""

ok "FPP Listener Sync removed. Reboot recommended."

