<?php
// =============================================================================
// about.php — FPP Phone Listener About Page
// =============================================================================
// Shown under Help > Phone Listener in FPP's menu.
// FPP's plugin.php wrapper provides the header/nav/footer.
// =============================================================================

$version = @file_get_contents(dirname(__FILE__) . '/VERSION') ?: 'unknown';
?>

<h3>FPP Phone Listener</h3>
<p>Version: <strong><?php echo htmlspecialchars($version); ?></strong></p>

<p>
    Synchronized audio for audience members via phone speakers. Creates a dedicated
    WiFi access point with captive portal, and uses WebSocket-based adaptive PLL
    sync to keep all connected phones in time with the FPP show.
</p>

<h4>How It Works</h4>
<ol>
    <li>A USB WiFi adapter creates an isolated "SHOW_AUDIO" network</li>
    <li>Phones connect and are directed to the listener page via captive portal</li>
    <li>A WebSocket server broadcasts the current show position every 100ms</li>
    <li>Each phone's browser adjusts its audio playback rate to stay in sync</li>
    <li>Typical sync accuracy: 5-25ms (imperceptible to the human ear)</li>
</ol>

<h4>Links</h4>
<ul>
    <li><a href="https://github.com/UndocEng/fpp-listener-sync" target="_blank" rel="noopener">GitHub Repository</a></li>
    <li><a href="https://github.com/UndocEng/fpp-listener-sync/issues" target="_blank" rel="noopener">Report a Bug</a></li>
</ul>

<h4>Credits</h4>
<p>
    Developed by <strong>UndocEng</strong>.<br>
    Built for the <a href="https://falconchristmas.com/" target="_blank" rel="noopener">Falcon Player</a> community.
</p>
