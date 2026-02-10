<?php
// Captive portal detection handler
// Different devices check different URLs to detect captive portals

$uri = $_SERVER['REQUEST_URI'] ?? '';

// Android/Chrome checks for generate_204 (expects HTTP 204 No Content)
if (strpos($uri, 'generate_204') !== false || strpos($uri, 'gen_204') !== false) {
    // Return redirect instead of 204 to trigger captive portal
    header('HTTP/1.1 302 Found');
    header('Location: http://192.168.50.1/listen/');
    exit;
}

// Apple iOS checks for success.html (expects specific HTML)
if (strpos($uri, 'success.html') !== false || strpos($uri, 'hotspot-detect.html') !== false) {
    header('HTTP/1.1 302 Found');
    header('Location: http://192.168.50.1/listen/');
    exit;
}

// Microsoft Windows checks for connecttest.txt
if (strpos($uri, 'connecttest.txt') !== false) {
    header('HTTP/1.1 302 Found');
    header('Location: http://192.168.50.1/listen/');
    exit;
}

// Ubuntu/Firefox checks for canonical.html
if (strpos($uri, 'canonical.html') !== false) {
    header('HTTP/1.1 302 Found');
    header('Location: http://192.168.50.1/listen/');
    exit;
}

// Default: redirect to listening page
header('HTTP/1.1 302 Found');
header('Location: http://192.168.50.1/listen/');
exit;
