<?php
header('Content-Type: text/plain');

// Debug version to see what's happening
$paths = [
    '/home/fpp/fpp-listener-sync/VERSION',
    __DIR__ . '/../../VERSION',
    dirname(__DIR__) . '/../VERSION'
];

echo "Debug Info:\n";
echo "Current directory: " . __DIR__ . "\n";
echo "Parent directory: " . dirname(__DIR__) . "\n\n";

foreach ($paths as $path) {
    echo "Checking: $path\n";
    echo "  Exists: " . (file_exists($path) ? 'YES' : 'NO') . "\n";
    if (file_exists($path)) {
        $content = @file_get_contents($path);
        echo "  Content: " . var_export($content, true) . "\n";
        echo "  Trimmed: " . trim($content) . "\n";
    }
    echo "\n";
}
