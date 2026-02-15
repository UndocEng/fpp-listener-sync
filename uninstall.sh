
#!/bin/bash
# =============================================================================
# uninstall.sh — FPP Listener Sync Uninstaller
# =============================================================================
#
# Reverses everything install.sh did:
#   1. Stops and removes systemd services (ws-sync, listener-ap, wlan1-setup)
#   2. Removes iptables rules (forwarding block, device isolation)
#   3. Restores original FPP configs from backups (dnsmasq, Apache, USB network)
#   4. Removes web files, symlinks, and the captive portal .htaccess
#   5. Brings down wlan1 and offers to reboot
#
# Run with: sudo ./uninstall.sh
# =============================================================================

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'

info()  { printf '%b\n' "${CYAN}[INFO]${NC} $1"; }

ok()    { printf '%b\n' "${GREEN}[OK]${NC} $1"; }

warn()  { printf '%b\n' "${YELLOW}[WARN]${NC} $1"; }

echo ""

echo "This will remove FPP Listener Sync and restore defaults."

printf "Continue? (y/N) "
read REPLY

[ "$REPLY" != "y" ] && [ "$REPLY" != "Y" ] && echo "Cancelled." && exit 0

# --- Stop and remove all listener-sync systemd services ---
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

sudo systemctl stop listen-mdns 2>/dev/null || true
sudo systemctl disable listen-mdns 2>/dev/null || true
sudo rm -f /etc/systemd/system/listen-mdns.service

sudo systemctl stop dnsmasq 2>/dev/null || true
sudo rm -rf /etc/systemd/system/dnsmasq.service.d

# --- Remove iptables rules added by install.sh ---
info "Removing iptables rules..."

if command -v iptables >/dev/null 2>&1; then
  sudo iptables -D FORWARD -i wlan1 -j DROP 2>/dev/null || true
  sudo iptables -D FORWARD -o wlan1 -j DROP 2>/dev/null || true
  sudo iptables -D INPUT -i wlan1 -m iprange --src-range 192.168.50.10-192.168.50.250 -d 192.168.50.1 -j ACCEPT 2>/dev/null || true
  sudo iptables -D INPUT -i wlan1 -s 192.168.50.0/24 -j DROP 2>/dev/null || true
  ok "iptables rules removed"
fi

# --- Remove network configs added by install.sh ---
info "Removing configs..."

sudo rm -f /etc/systemd/network/20-listener-ap.network
sudo rm -f /etc/sysctl.d/99-no-forward.conf

# --- Restore original FPP configs from backups ---
# install.sh renamed these to .disabled; restore them so FPP's USB tethering works again
info "Restoring FPP configs..."

[ -f /etc/dnsmasq.d/usb.conf.disabled ] && sudo mv /etc/dnsmasq.d/usb.conf.disabled /etc/dnsmasq.d/usb.conf && ok "Restored usb.conf"

[ -f /etc/systemd/network/usb1.network.disabled ] && sudo mv /etc/systemd/network/usb1.network.disabled /etc/systemd/network/usb1.network && ok "Restored usb1.network"

# Restore dnsmasq.conf from the backup made during install
if [ -f /etc/dnsmasq.conf.listener-backup ]; then
  sudo mv /etc/dnsmasq.conf.listener-backup /etc/dnsmasq.conf
  ok "Restored original dnsmasq.conf"
else
  warn "No dnsmasq.conf backup found - original config not restored"
fi

sudo systemctl restart dnsmasq 2>/dev/null || true

# --- Restore Apache config ---
# install.sh changed AllowOverride None to AllowOverride All and added listener.conf.
# Restore from backup and remove our additions.
info "Restoring Apache config..."
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

# --- Remove all web files, symlinks, and runtime data ---
info "Removing web files..."

sudo rm -rf /opt/fpp/www/listen       # symlink to listen web files
sudo rm -f /opt/fpp/www/music          # symlink to FPP music directory
sudo rm -f /opt/fpp/www/.htaccess      # captive portal redirect rules
sudo rm -f /opt/fpp/www/qrcode.html    # QR code generator page
sudo rm -f /opt/fpp/www/print-sign.html # printable sign
sudo rm -f /opt/fpp/www/qrcode.min.js  # QR code JS library

sudo rm -rf /home/fpp/media/www/listen  # actual web files
sudo rm -rf /home/fpp/listen-sync       # runtime dir (server, hostapd config, sync.log)

info "Restarting Apache..."

sudo systemctl restart apache2 2>/dev/null || sudo systemctl restart httpd 2>/dev/null || true

info "Reloading systemd..."

sudo systemctl daemon-reload

info "Bringing down wlan1..."

sudo ip link set wlan1 down 2>/dev/null || true
sudo ip addr flush dev wlan1 2>/dev/null || true

echo ""

ok "FPP Listener Sync removed. Reboot recommended."

echo ""
printf "Reboot now? (y/N) "
read REPLY
[ "$REPLY" = "y" ] || [ "$REPLY" = "Y" ] && sudo reboot

