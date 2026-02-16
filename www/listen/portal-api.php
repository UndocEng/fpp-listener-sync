<?php
/**
 * portal-api.php — Captive Portal API (RFC 8908/8910)
 * ====================================================
 *
 * Implements the Captive Portal API for modern devices (Android 11+, iOS 14+).
 * Referenced by DHCP option 114 in dnsmasq.conf.
 *
 * When a device connects to SHOW_AUDIO, DHCP option 114 tells it to fetch
 * this URL. The JSON response tells the device:
 *   - "captive": true  → this network requires sign-in
 *   - "user-portal-url" → where to open the sign-in page
 *
 * The device then shows a "Sign in to Wi-Fi network" notification/popup.
 */

header('Content-Type: application/captive+json');
header('Cache-Control: private, no-store, max-age=0');

echo json_encode([
    'captive' => true,
    'user-portal-url' => 'http://192.168.50.1/listen/'
], JSON_UNESCAPED_SLASHES);
