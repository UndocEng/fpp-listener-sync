<?php
header('Content-Type: text/plain');

// Try multiple possible paths for VERSION file
$paths = [
    __DIR__ . '/VERSION',
    '/home/fpp/fpp-listener-sync/VERSION',
    __DIR__ . '/../../VERSION',
    '../VERSION'
];

$version = '1.2.0'; // Fallback version

foreach ($paths as $path) {
    if (file_exists($path)) {
        $content = @file_get_contents($path);
        if ($content !== false && trim($content) !== '') {
            $version = trim($content);
            break;
        }
    }
}

echo $version;
