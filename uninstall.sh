
#!/bin/bash

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC} $1"; }

ok()    { echo -e "${GREEN}[OK]${NC} $1"; }

echo ""

echo "This will remove FPP Listener Sync and restore defaults."

read -p "Continue? (y/N) " -n 1 -r

echo ""

[[ ! $REPLY =~ ^[Yy]$ ]] && echo "Cancelled." && exit 0

info "Stopping services..."

sudo systemctl stop listener-ap 2>/dev/null || true

sudo systemctl disable listener-ap 2>/dev/null || true

sudo rm -f /etc/systemd/system/listener-ap.service

sudo systemctl stop dnsmasq 2>/dev/null || true

sudo rm -rf /etc/systemd/system/dnsmasq.service.d

info "Removing configs..."

sudo rm -f /etc/systemd/network/20-listener-ap.network

sudo rm -f /etc/sysctl.d/99-no-forward.conf

info "Restoring FPP configs..."

[ -f /etc/dnsmasq.d/usb.conf.disabled ] && sudo mv /etc/dnsmasq.d/usb.conf.disabled /etc/dnsmasq.d/usb.conf

[ -f /etc/systemd/network/usb1.network.disabled ] && sudo mv /etc/systemd/network/usb1.network.disabled /etc/systemd/network/usb1.network

info "Removing web files..."

sudo rm -rf /opt/fpp/www/listen

sudo rm -f /opt/fpp/www/music

sudo rm -rf /home/fpp/media/www/listen

sudo rm -rf /home/fpp/listen-sync

info "Reloading systemd..."

sudo systemctl daemon-reload

sudo systemctl restart systemd-networkd 2>/dev/null || true

echo ""

ok "FPP Listener Sync removed. Reboot recommended."

