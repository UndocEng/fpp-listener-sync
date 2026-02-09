<?php
header('Content-Type: text/plain');
$version = @file_get_contents('/home/fpp/fpp-listener-sync/VERSION');
echo $version !== false ? trim($version) : '1.0.0';
