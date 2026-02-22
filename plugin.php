<?php
// =============================================================================
// plugin.php — FPP Phone Listener Admin Dashboard
// =============================================================================
// This is the main plugin page. FPP's plugin.php handler wraps it with the
// standard FPP header, navbar, and footer. jQuery and Bootstrap 5 are available.
//
// Tabs: Status | AP Configuration | Connected Clients | Logs & Diagnostics
// =============================================================================

$version = @file_get_contents(dirname(__FILE__) . '/VERSION') ?: 'unknown';
?>

<!-- Tab Navigation -->
<ul class="nav nav-tabs" id="listenerTabs" role="tablist">
    <li class="nav-item" role="presentation">
        <button class="nav-link active" id="status-tab" data-bs-toggle="tab" data-bs-target="#statusPanel"
            type="button" role="tab">Status</button>
    </li>
    <li class="nav-item" role="presentation">
        <button class="nav-link" id="config-tab" data-bs-toggle="tab" data-bs-target="#configPanel"
            type="button" role="tab">AP Configuration</button>
    </li>
    <li class="nav-item" role="presentation">
        <button class="nav-link" id="clients-tab" data-bs-toggle="tab" data-bs-target="#clientsPanel"
            type="button" role="tab">Connected Clients</button>
    </li>
    <li class="nav-item" role="presentation">
        <button class="nav-link" id="logs-tab" data-bs-toggle="tab" data-bs-target="#logsPanel"
            type="button" role="tab">Logs & Diagnostics</button>
    </li>
</ul>

<div class="tab-content mt-3" id="listenerTabContent">

    <!-- ====== STATUS TAB ====== -->
    <div class="tab-pane fade show active" id="statusPanel" role="tabpanel">
        <div class="row">
            <div class="col-md-6">
                <h3>Services</h3>
                <table class="table table-sm">
                    <tbody>
                        <tr><td>Listener AP (hostapd)</td><td id="svc-listener-ap">--</td></tr>
                        <tr><td>DNS/DHCP (dnsmasq)</td><td id="svc-dnsmasq">--</td></tr>
                        <tr><td>WebSocket Sync (ws-sync)</td><td id="svc-ws-sync">--</td></tr>
                        <tr><td>Firewall (nftables)</td><td id="svc-nftables">--</td></tr>
                    </tbody>
                </table>
            </div>
            <div class="col-md-6">
                <h3>Current AP</h3>
                <table class="table table-sm">
                    <tbody>
                        <tr><td>SSID</td><td id="cur-ssid">--</td></tr>
                        <tr><td>Interface</td><td id="cur-iface">--</td></tr>
                        <tr><td>Channel</td><td id="cur-channel">--</td></tr>
                        <tr><td>IP Address</td><td id="cur-ip">--</td></tr>
                        <tr><td>Connected Clients</td><td id="cur-clients">--</td></tr>
                    </tbody>
                </table>
            </div>
        </div>

        <h3>Quick Links</h3>
        <div class="mb-3">
            <a id="link-listener" href="#" target="_blank" class="btn btn-outline-light btn-sm me-2">
                <i class="fas fa-broadcast-tower"></i> Open Listener Page
            </a>
            <a href="networkconfig.php" class="btn btn-outline-light btn-sm me-2">
                <i class="fas fa-network-wired"></i> FPP Network Settings
            </a>
            <a id="link-qrcode" href="#" target="_blank" class="btn btn-outline-light btn-sm me-2">
                <i class="fas fa-qrcode"></i> QR Code
            </a>
            <a id="link-sign" href="#" target="_blank" class="btn btn-outline-light btn-sm">
                <i class="fas fa-print"></i> Print Sign
            </a>
        </div>

        <div class="text-muted">
            FPP Phone Listener v<?php echo htmlspecialchars($version); ?>
        </div>
    </div>

    <!-- ====== AP CONFIGURATION TAB ====== -->
    <div class="tab-pane fade" id="configPanel" role="tabpanel">
        <h3>Access Point Settings</h3>

        <div class="row mb-3">
            <label class="col-md-3 col-form-label">WiFi Interface</label>
            <div class="col-md-5">
                <select id="cfg-iface" class="form-select">
                    <option value="wlan1">wlan1 (USB adapter)</option>
                </select>
            </div>
        </div>

        <div class="row mb-3">
            <label class="col-md-3 col-form-label">Network Name (SSID)</label>
            <div class="col-md-5">
                <input type="text" id="cfg-ssid" class="form-control" maxlength="32" placeholder="SHOW_AUDIO">
            </div>
        </div>

        <div class="row mb-3">
            <label class="col-md-3 col-form-label">Password</label>
            <div class="col-md-5">
                <input type="password" id="cfg-password" class="form-control" maxlength="63"
                    placeholder="Open (no password)">
                <div class="form-text">Leave blank for an open network. 8-63 characters for WPA2.</div>
            </div>
        </div>

        <div class="row mb-3">
            <label class="col-md-3 col-form-label">Channel</label>
            <div class="col-md-5">
                <select id="cfg-channel" class="form-select">
                    <option value="1">1</option>
                    <option value="2">2</option>
                    <option value="3">3</option>
                    <option value="4">4</option>
                    <option value="5">5</option>
                    <option value="6" selected>6</option>
                    <option value="7">7</option>
                    <option value="8">8</option>
                    <option value="9">9</option>
                    <option value="10">10</option>
                    <option value="11">11</option>
                </select>
            </div>
        </div>

        <div class="row mb-3">
            <label class="col-md-3 col-form-label">AP IP Address</label>
            <div class="col-md-5">
                <input type="text" id="cfg-ip" class="form-control" placeholder="192.168.50.1">
                <div class="form-text">Changing the IP will update dnsmasq, nftables, captive portal, and .htaccess.</div>
            </div>
        </div>

        <div class="row mb-3">
            <div class="col-md-5 offset-md-3">
                <button id="btn-save-config" class="btn btn-success">
                    <i class="fas fa-save"></i> Save & Restart AP
                </button>
                <span id="save-status" class="ms-2"></span>
            </div>
        </div>
    </div>

    <!-- ====== CONNECTED CLIENTS TAB ====== -->
    <div class="tab-pane fade" id="clientsPanel" role="tabpanel">
        <div class="d-flex justify-content-between align-items-center mb-3">
            <h3 class="mb-0">Connected Clients</h3>
            <div>
                <label class="form-check-label me-2">
                    <input type="checkbox" id="auto-refresh-clients" class="form-check-input" checked>
                    Auto-refresh
                </label>
                <button id="btn-refresh-clients" class="btn btn-outline-light btn-sm">
                    <i class="fas fa-sync-alt"></i> Refresh
                </button>
            </div>
        </div>
        <table class="table table-sm table-striped" id="clients-table">
            <thead>
                <tr>
                    <th>MAC Address</th>
                    <th>IP</th>
                    <th>Hostname</th>
                    <th>Signal</th>
                    <th>Connected</th>
                </tr>
            </thead>
            <tbody id="clients-tbody">
                <tr><td colspan="5" class="text-muted">Loading...</td></tr>
            </tbody>
        </table>
    </div>

    <!-- ====== LOGS & DIAGNOSTICS TAB ====== -->
    <div class="tab-pane fade" id="logsPanel" role="tabpanel">
        <h3>Diagnostics</h3>
        <div class="mb-3">
            <button id="btn-selftest" class="btn btn-outline-light btn-sm">
                <i class="fas fa-stethoscope"></i> Run Self-Test
            </button>
            <button id="btn-restart-ap" class="btn btn-outline-warning btn-sm ms-2">
                <i class="fas fa-redo"></i> Restart AP
            </button>
            <button id="btn-restart-ws" class="btn btn-outline-warning btn-sm ms-2">
                <i class="fas fa-redo"></i> Restart WS Sync
            </button>
            <button id="btn-restart-dns" class="btn btn-outline-warning btn-sm ms-2">
                <i class="fas fa-redo"></i> Restart DNS/DHCP
            </button>
        </div>
        <div id="selftest-results" class="mb-3" style="display:none;"></div>

        <h3>Service Logs</h3>
        <div class="mb-2">
            <select id="log-source" class="form-select d-inline-block" style="width:auto;">
                <option value="ws-sync">WebSocket Sync</option>
                <option value="listener-ap">Listener AP</option>
                <option value="dnsmasq">DNS/DHCP</option>
                <option value="sync">Sync Reports</option>
            </select>
            <select id="log-lines" class="form-select d-inline-block ms-1" style="width:auto;">
                <option value="25">25 lines</option>
                <option value="50" selected>50 lines</option>
                <option value="100">100 lines</option>
                <option value="200">200 lines</option>
            </select>
            <button id="btn-load-logs" class="btn btn-outline-light btn-sm ms-1">
                <i class="fas fa-file-alt"></i> Load
            </button>
        </div>
        <pre id="log-output" class="p-2" style="max-height:400px; overflow-y:auto; font-size:12px; background:#1a1a2e; color:#e0e0e0; border:1px solid #333; border-radius:4px;">Select a log source and click Load.</pre>
    </div>

</div>
