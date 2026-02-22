<?php
// FPP Plugin Menu Entries for FPP Phone Listener
// This file is included by FPP's menu.inc for each dropdown section.
// $menu = current section being rendered (status, content, output, help)
// $plugin = this plugin's directory name

if ($menu == "status") {
    printf("<li><a href='plugin.php?plugin=%s&page=plugin.php'><i class='fas fa-broadcast-tower'></i> Phone Listener</a></li>\n", $plugin);
}

if ($menu == "help") {
    printf("<li><a href='plugin.php?plugin=%s&page=about.php'><i class='fas fa-info-circle'></i> Phone Listener</a></li>\n", $plugin);
}
?>
