#!/bin/bash
# =============================================================================
# fpp_uninstall.sh — FPP Phone Listener Plugin Uninstall Script
# =============================================================================
# Called by FPP's plugin manager before removing the plugin, or manually via:
#   sudo ./scripts/fpp_uninstall.sh
#
# Reverses everything fpp_install.sh did. FPP's network settings
# (/home/fpp/media/config/interface.*) are NOT touched — they survive uninstall.
# =============================================================================

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { printf '%b\n' "${CYAN}[INFO]${NC} $1"; }
ok()    { printf '%b\n' "${GREEN}[OK]${NC} $1"; }
warn()  { printf '%b\n' "${YELLOW}[WARN]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION=$(cat "$PLUGIN_DIR/VERSION" 2>/dev/null || echo "unknown")

echo ""
info "Uninstalling FPP Phone Listener v${VERSION}..."

# --- Stop and remove systemd services ---
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
ok "Services stopped"

# --- Remove nftables firewall rules ---
info "Removing nftables firewall rules..."
if [ -x /usr/sbin/nft ]; then
  sudo /usr/sbin/nft delete table inet listener_filter 2>/dev/null || true
  ok "nftables rules removed"
fi

# --- Remove network configs ---
info "Removing network configs..."
sudo rm -f /etc/systemd/network/20-listener-ap.network
sudo rm -f /etc/sysctl.d/99-no-forward.conf

# --- Restore original FPP configs ---
info "Restoring FPP configs..."
[ -f /etc/dnsmasq.d/usb.conf.disabled ] && sudo mv /etc/dnsmasq.d/usb.conf.disabled /etc/dnsmasq.d/usb.conf && ok "Restored usb.conf"
[ -f /etc/systemd/network/usb1.network.disabled ] && sudo mv /etc/systemd/network/usb1.network.disabled /etc/systemd/network/usb1.network && ok "Restored usb1.network"

if [ -f /etc/dnsmasq.conf.listener-backup ]; then
  sudo mv /etc/dnsmasq.conf.listener-backup /etc/dnsmasq.conf
  ok "Restored original dnsmasq.conf"
else
  warn "No dnsmasq.conf backup found"
fi
sudo systemctl restart dnsmasq 2>/dev/null || true

# --- Restore Apache config ---
info "Restoring Apache config..."
if [ -f /etc/apache2/sites-enabled/000-default.conf.listener-backup ]; then
  sudo mv /etc/apache2/sites-enabled/000-default.conf.listener-backup /etc/apache2/sites-enabled/000-default.conf
  ok "Restored Apache config"
else
  warn "No Apache config backup found"
fi
sudo rm -f /etc/apache2/conf-available/listener.conf
sudo rm -f /etc/apache2/conf-enabled/listener.conf
sudo a2disconf listener 2>/dev/null || true

# --- Restore network config page ---
info "Restoring network config page..."
if [ -f /opt/fpp/www/networkconfig.php.listener-backup ]; then
  sudo mv /opt/fpp/www/networkconfig.php.listener-backup /opt/fpp/www/networkconfig.php
  ok "Restored original networkconfig.php"
else
  warn "No networkconfig.php backup found"
fi

# --- Remove sudoers ---
info "Removing sudoers..."
sudo rm -f /etc/sudoers.d/fpp-listener
ok "Sudoers removed"

# --- Remove web files ---
info "Removing web files..."
sudo rm -rf /opt/fpp/www/listen
sudo rm -f /opt/fpp/www/music
sudo rm -f /opt/fpp/www/.htaccess
sudo rm -f /opt/fpp/www/qrcode.html
sudo rm -f /opt/fpp/www/print-sign.html
sudo rm -f /opt/fpp/www/qrcode.min.js
sudo rm -rf /home/fpp/media/www/listen
sudo rm -rf /home/fpp/listen-sync

# --- Restart Apache ---
info "Restarting Apache..."
sudo systemctl restart apache2 2>/dev/null || sudo systemctl restart httpd 2>/dev/null || true

# --- Reload systemd ---
sudo systemctl daemon-reload

# --- Bring down wlan1 ---
info "Bringing down wlan1..."
sudo ip link set wlan1 down 2>/dev/null || true
sudo ip addr flush dev wlan1 2>/dev/null || true

echo ""
echo "========================================="
printf '%b\n' "${GREEN}  Uninstall successful! (was v${VERSION})${NC}"
echo "========================================="
echo ""
info "FPP network settings are preserved. Reboot recommended."
