// =============================================================================
// listener-admin.js — FPP Phone Listener Admin Dashboard
// =============================================================================
// Handles all AJAX interactions with listener-api.php for the admin dashboard.
// jQuery and Bootstrap 5 are provided by FPP's plugin.php wrapper.
// =============================================================================

var pluginName = 'fpp-listener-sync';
var clientRefreshTimer = null;

// Helper: call plugin API
function apiCall(action, data, callback) {
    var fd = new FormData();
    fd.append('action', action);
    if (data) {
        for (var k in data) fd.append(k, data[k]);
    }
    $.ajax({
        url: 'plugin.php?plugin=' + pluginName + '&page=listener-api.php&nopage=1',
        method: 'POST',
        data: fd,
        processData: false,
        contentType: false,
        dataType: 'json',
        success: function(res) { callback(res); },
        error: function(xhr) {
            callback({ success: false, error: 'Request failed: ' + xhr.status });
        }
    });
}

// Service status badge
function statusBadge(status) {
    if (status === 'active') return '<span class="badge bg-success">Running</span>';
    if (status === 'inactive') return '<span class="badge bg-secondary">Stopped</span>';
    if (status === 'failed') return '<span class="badge bg-danger">Failed</span>';
    return '<span class="badge bg-warning">' + status + '</span>';
}

// =============================================================================
// Status Tab
// =============================================================================
function loadStatus() {
    apiCall('get_status', null, function(res) {
        if (!res.success) return;
        $('#svc-listener-ap').html(statusBadge(res.services['listener-ap']));
        $('#svc-dnsmasq').html(statusBadge(res.services['dnsmasq']));
        $('#svc-ws-sync').html(statusBadge(res.services['ws-sync']));
        $('#svc-nftables').html(statusBadge(res.services['nftables']));
        $('#cur-ssid').text(res.ssid || '--');
        $('#cur-iface').text(res.interface || '--');
        $('#cur-channel').text(res.channel || '--');
        $('#cur-ip').text(res.wlanIP || '--');
        $('#cur-clients').text(res.clientCount);

        // Update quick links with actual IP
        var ip = (res.wlanIP || '192.168.50.1').replace(/\/.*/, '');
        $('#link-listener').attr('href', 'http://' + ip + '/listen/');
        $('#link-qrcode').attr('href', 'http://' + ip + '/qrcode.html');
        $('#link-sign').attr('href', 'http://' + ip + '/print-sign.html');
    });
}

// =============================================================================
// AP Configuration Tab
// =============================================================================
function loadConfig() {
    apiCall('get_config', null, function(res) {
        if (!res.success) return;
        var cfg = res.config;
        $('#cfg-ssid').val(cfg.ssid);
        $('#cfg-channel').val(cfg.channel);
        $('#cfg-ip').val(cfg.ap_ip);
        $('#cfg-password').val('');

        // Populate interface dropdown
        var sel = $('#cfg-iface');
        sel.empty();
        if (cfg.interfaces && cfg.interfaces.length) {
            cfg.interfaces.forEach(function(iface) {
                var label = iface.name;
                if (iface.name === 'wlan0') label += ' (onboard)';
                else if (iface.name === 'wlan1') label += ' (USB adapter)';
                sel.append($('<option>').val(iface.name).text(label));
            });
        } else {
            sel.append($('<option>').val('wlan1').text('wlan1 (USB adapter)'));
        }
        sel.val(cfg.interface);
    });
}

function saveConfig() {
    var data = {
        interface: $('#cfg-iface').val(),
        ssid: $('#cfg-ssid').val(),
        channel: $('#cfg-channel').val(),
        password: $('#cfg-password').val(),
        ap_ip: $('#cfg-ip').val()
    };

    if (!data.ssid) {
        $('#save-status').html('<span class="text-danger">SSID is required</span>');
        return;
    }

    var ipChanged = data.ap_ip !== ($('#cur-ip').text() || '').replace(/\/.*/, '');
    var msg = 'Save settings and restart the AP?';
    if (ipChanged) {
        msg += '\n\nWARNING: IP address is changing. Connected devices will disconnect. You may need to reconnect to the new address.';
    }

    if (!confirm(msg)) return;

    $('#btn-save-config').prop('disabled', true);
    $('#save-status').html('<i class="fas fa-spinner fa-spin"></i> Saving...');

    apiCall('save_config', data, function(res) {
        $('#btn-save-config').prop('disabled', false);
        if (res.success) {
            $('#save-status').html('<span class="text-success">' + res.message + '</span>');
            setTimeout(function() {
                loadStatus();
                loadConfig();
            }, 3000);
        } else {
            $('#save-status').html('<span class="text-danger">' + res.error + '</span>');
        }
    });
}

// =============================================================================
// Connected Clients Tab
// =============================================================================
function loadClients() {
    apiCall('get_clients', null, function(res) {
        var tbody = $('#clients-tbody');
        tbody.empty();
        if (!res.success || !res.clients || !res.clients.length) {
            tbody.html('<tr><td colspan="5" class="text-muted">No clients connected</td></tr>');
            return;
        }
        res.clients.forEach(function(c) {
            var signal = c.signal || '--';
            var signalClass = '';
            if (c.signal) {
                var dbm = parseInt(c.signal);
                if (dbm >= -50) signalClass = 'text-success';
                else if (dbm >= -70) signalClass = 'text-warning';
                else signalClass = 'text-danger';
            }
            tbody.append(
                '<tr>' +
                '<td><code>' + (c.mac || '--') + '</code></td>' +
                '<td>' + (c.ip || '--') + '</td>' +
                '<td>' + (c.hostname || '--') + '</td>' +
                '<td class="' + signalClass + '">' + signal + '</td>' +
                '<td>' + (c.connected || '--') + '</td>' +
                '</tr>'
            );
        });
    });
}

function startClientRefresh() {
    if (clientRefreshTimer) clearInterval(clientRefreshTimer);
    clientRefreshTimer = setInterval(function() {
        if ($('#auto-refresh-clients').is(':checked') && $('#clientsPanel').hasClass('active')) {
            loadClients();
        }
    }, 5000);
}

// =============================================================================
// Logs & Diagnostics Tab
// =============================================================================
function loadLogs() {
    var source = $('#log-source').val();
    var lines = $('#log-lines').val();
    $('#log-output').text('Loading...');
    apiCall('get_logs', { source: source, lines: lines }, function(res) {
        if (res.success) {
            $('#log-output').text(res.log || '(empty)');
            // Auto-scroll to bottom
            var el = document.getElementById('log-output');
            el.scrollTop = el.scrollHeight;
        } else {
            $('#log-output').text('Error: ' + res.error);
        }
    });
}

function runSelfTest() {
    $('#btn-selftest').prop('disabled', true).html('<i class="fas fa-spinner fa-spin"></i> Testing...');
    apiCall('selftest', null, function(res) {
        $('#btn-selftest').prop('disabled', false).html('<i class="fas fa-stethoscope"></i> Run Self-Test');
        if (!res.success) {
            $('#selftest-results').show().html('<div class="alert alert-danger">Self-test failed to run</div>');
            return;
        }
        var html = '<table class="table table-sm">';
        res.results.forEach(function(r) {
            var icon = r.pass ? '<i class="fas fa-check-circle text-success"></i>' : '<i class="fas fa-times-circle text-danger"></i>';
            html += '<tr><td>' + icon + '</td><td>' + r.test + '</td><td>' + r.detail + '</td></tr>';
        });
        html += '</table>';
        var alertClass = res.allPass ? 'alert-success' : 'alert-warning';
        var summary = res.allPass ? 'All checks passed!' : 'Some checks failed.';
        $('#selftest-results').show().html('<div class="alert ' + alertClass + '">' + summary + '</div>' + html);
    });
}

function restartServiceBtn(service) {
    if (!confirm('Restart ' + service + '?')) return;
    apiCall('restart_service', { service: service }, function(res) {
        if (res.success) {
            $.jGrowl(res.message, { themeState: 'success' });
        } else {
            $.jGrowl(res.error || 'Failed', { themeState: 'danger' });
        }
        setTimeout(loadStatus, 2000);
    });
}

// =============================================================================
// Initialize
// =============================================================================
$(document).ready(function() {
    // Load initial data
    loadStatus();
    loadConfig();

    // Tab change handlers
    $('button[data-bs-toggle="tab"]').on('shown.bs.tab', function(e) {
        var target = $(e.target).data('bs-target');
        if (target === '#clientsPanel') loadClients();
        if (target === '#statusPanel') loadStatus();
    });

    // Button handlers
    $('#btn-save-config').on('click', saveConfig);
    $('#btn-refresh-clients').on('click', loadClients);
    $('#btn-selftest').on('click', runSelfTest);
    $('#btn-load-logs').on('click', loadLogs);
    $('#btn-restart-ap').on('click', function() { restartServiceBtn('listener-ap'); });
    $('#btn-restart-ws').on('click', function() { restartServiceBtn('ws-sync'); });
    $('#btn-restart-dns').on('click', function() { restartServiceBtn('dnsmasq'); });

    // Auto-refresh clients
    startClientRefresh();

    // Refresh status every 30s
    setInterval(loadStatus, 30000);
});
