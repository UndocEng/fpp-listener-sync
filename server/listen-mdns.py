#!/usr/bin/env python3
# =============================================================================
# listen-mdns.py — Publish "listen.local" via Avahi mDNS on wlan1 only
# =============================================================================
#
# Problem: The ".local" TLD is reserved for mDNS (RFC 6762). Phones route
#          .local queries to multicast DNS (port 5353), NOT to dnsmasq (port 53).
#          So dnsmasq's "address=/listen.local/192.168.50.1" is never queried.
#
# Solution: Use Avahi's D-Bus API to publish an mDNS address record for
#           "listen.local" pointing to 192.168.50.1, restricted to the wlan1
#           interface only. This way phones on the SHOW_AUDIO network can
#           resolve listen.local, but other interfaces (wlan0, eth0) are
#           not affected.
#
# Runs as: systemd service (listen-mdns.service), started by install.sh
# =============================================================================

import dbus
import socket
import signal
import time
import sys

IFACE = 'wlan1'
HOSTNAME = 'listen.local'
ADDRESS = '192.168.50.1'

def main():
    try:
        ifindex = socket.if_nametoindex(IFACE)
    except OSError:
        print(f"Interface {IFACE} not found, exiting")
        sys.exit(1)

    bus = dbus.SystemBus()
    server = dbus.Interface(
        bus.get_object('org.freedesktop.Avahi', '/'),
        'org.freedesktop.Avahi.Server'
    )

    group = dbus.Interface(
        bus.get_object('org.freedesktop.Avahi', server.EntryGroupNew()),
        'org.freedesktop.Avahi.EntryGroup'
    )

    # AddAddress(interface, protocol, flags, name, address)
    #   interface: OS interface index (wlan1 only)
    #   protocol:  0 = IPv4
    #   flags:     0 = none
    group.AddAddress(ifindex, 0, 0, HOSTNAME, ADDRESS)
    group.Commit()

    print(f"Publishing {HOSTNAME} -> {ADDRESS} on {IFACE} (ifindex={ifindex})")

    # Keep running until systemd sends SIGTERM
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    signal.signal(signal.SIGINT, lambda *_: sys.exit(0))
    while True:
        time.sleep(3600)

if __name__ == '__main__':
    main()
