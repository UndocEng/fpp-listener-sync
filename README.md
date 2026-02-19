
# FPP Listener Sync

**Stream synced show audio to visitor phones — no app, no FM transmitter, no speakers.**

Visitors connect to an open Wi-Fi AP, open a URL, and hear show audio synced to the currently playing FPP sequence — right from their phone browser.

## How It Works

1. FPP plays sequences (`.fseq`) with matching `.mp3` files as normal
2. A USB Wi-Fi adapter on the Pi broadcasts an open Wi-Fi network called `SHOW_AUDIO`
3. Visitors join the Wi-Fi and a captive portal page opens automatically
4. They tap **Enable Audio** and the browser downloads the MP3
5. A WebSocket connection to the Pi keeps the audio synced to FPP's current position
6. No app install required — works in Safari, Chrome, Firefox on any phone

7. ## Support This Project

If this tool saved you time or made your show better, consider buying me a coffee or donate for me to get more tokkens:

[![PayPal](https://img.shields.io/badge/PayPal-Donate-blue?logo=paypal)](https://www.paypal.com/ncp/payment/Y66WZAYUA5ED6)

<!--
For non-GitHub pages that support scripts, use the hosted button:
<div id="paypal-container-Y66WZAYUA5ED6"></div>
<script>
  paypal.HostedButtons({
    hostedButtonId: "Y66WZAYUA5ED6",
  }).render("#paypal-container-Y66WZAYUA5ED6")
</script>
-->


---

## Important

**Music Licensing**: You are responsible for ensuring you have the proper rights and permissions to broadcast any music used with this system. This includes public performance licenses (ASCAP, BMI, SESAC, etc.) as required by your local laws. Modify and use at your own risk.

## Requirements

- Raspberry Pi running FPP v9.x (tested on Pi 3B with FPP v9.4)
- USB Wi-Fi adapter (nl80211-compatible, e.g. rtl8192cu) — this is the second Wi-Fi that creates the `SHOW_AUDIO` network
- Apache + PHP (already included in standard FPP images)
- Python 3 with `websockets` package (the installer will install this for you)
- `.fseq` and audio files must share the same base filename (e.g. `MySong.fseq` and `MySong.mp3`)
- Supported audio formats: MP3, M4A, AAC, OGG, WAV (MP3 is strongly recommended for best compatibility)

## Getting Started — Step by Step

### Step 1: Plug In Your USB Wi-Fi Adapter

Plug a USB Wi-Fi adapter into one of the Pi's USB ports. This adapter will broadcast the `SHOW_AUDIO` network for visitors. Your Pi's built-in Wi-Fi (wlan0) stays connected to your home/show network as normal.

### Step 2: Open a Terminal on Your Pi

You need to type commands into your Pi. There are three ways to do this:

**Option A — From the FPP Web Interface (Easiest)**
1. Open your browser and go to `http://fpp.local` (or your Pi's IP address)
2. Click the **Help** menu (top right corner)
3. Select **SSH Shell**
4. A black terminal window opens right in your browser — you're ready to type commands

**Option B — From Windows**
1. Open **Windows Terminal** or download [PuTTY](https://www.putty.org/)
2. Connect to host: `fpp.local` (or your Pi's IP address), port: `22`
3. When prompted, enter:
   - Username: `fpp`
   - Password: `falcon`

**Option C — From Mac or Linux**
1. Open Terminal
2. Type: `ssh fpp@fpp.local` and press Enter
3. Enter password: `falcon`

### Step 3: Install FPP Listener Sync

Copy and paste these commands one at a time into the terminal, pressing Enter after each one:

```bash
cd /home/fpp
```

```bash
git clone https://github.com/UndocEng/fpp-listener-sync.git
```

```bash
cd fpp-listener-sync
```

```bash
sudo ./install.sh
```

The installer will automatically:
- Install all required packages (hostapd, dnsmasq, python3-websockets)
- Set up the `SHOW_AUDIO` Wi-Fi network on your USB adapter
- Configure the captive portal so phones open the page automatically
- Deploy the web files and WebSocket sync server
- Start all services
- Run a self-test to make sure everything is working

When it finishes, you should see **"All checks passed. Ready to go!"** in green.

### Step 4: Upload Your Music

Your audio files need to be in FPP's music folder. The easiest way:

1. Open the FPP web interface (`http://fpp.local`)
2. Go to **Content Setup** > **File Manager**
3. Upload your `.mp3` files to the **Music** folder

**The filenames must match your sequences exactly.** For example:
- Sequence file: `JingleBells.fseq`
- Audio file: `JingleBells.mp3`

If the names don't match, visitors won't hear any audio for that sequence.

### Step 5: Test It

1. Start a sequence playing on FPP
2. On your phone, join the **SHOW_AUDIO** Wi-Fi network (no password needed)
3. A captive portal page should pop up automatically. If it doesn't, open your browser and go to `192.168.50.1/listen/`
4. Tap **Enable Audio**
5. You should hear the music synced to your show!

## How the Sync Works

### Initial Start (How Audio Begins)

When a track starts playing or a phone joins mid-song:

1. The browser **seeks to FPP's current position** and presses **play** immediately
2. **Play-ahead latency compensation** fires `play()` slightly early to account for the device's audio startup delay (see below)
3. After a 3-second **settle period**, the PLL takes over to correct any remaining error smoothly

### Play-Ahead Latency Compensation

Different devices take different amounts of time to actually start outputting sound after `play()` is called. A phone might take 50ms; a PC browser might take 200ms.

The system **measures this delay** the first time it plays on each device, stores the measurement, and on subsequent plays it fires `play()` that much **earlier** to compensate. This brings all devices closer together regardless of their hardware.

The measured play latency is shown in the debug panel and saved to the device's browser storage so it persists across sessions.

### PLL (Phase-Locked Loop) — Continuous Sync

Instead of pausing and re-seeking when audio drifts (which causes audible glitches), the system uses a **PLL** to make tiny, inaudible adjustments to the playback speed:

1. **Calibration** (~1 second after settle): Collects position samples and computes the device's natural `baseRate` via least-squares regression
2. **Locked**: Continuously adjusts `playbackRate` based on the **2-second rolling average error** (`avg2s`)
   - **Adaptive gain**: Corrections are aggressive when error is large, gentle when error is small
   - **Log-compressed**: Large errors get proportionally smaller corrections to avoid overshooting
   - **Dead zone (5ms)**: No corrections when avg2s is within 5ms — avoids jitter from measurement noise
   - **Rate learning**: The base rate is slowly updated via EMA to track long-term drift

The PLL typically converges to within **10-25ms** of FPP within 10-17 seconds, and stays there for the duration of the song. The playback speed adjustments are tiny (less than 1%) and completely inaudible.

A **hard seek** is only performed if error exceeds 2 seconds (e.g., after a long network dropout), followed by re-calibration.

### Transport

- **WebSocket** (primary): 100ms updates from the Pi, NTP-style clock offset estimation
- **HTTP polling** (fallback): Automatic fallback if WebSocket is unavailable
- Clock offset between the phone and Pi is estimated using NTP-style ping/pong measurements over WebSocket

## Measured Performance (v2.3.5)

Real-world sync log data from a Samsung S21 on the SHOW_AUDIO network, measured across 5 track sessions (~11 minutes total, 564 steady-state samples):

### Convergence

| Scenario | Typical Convergence Time |
|----------|--------------------------|
| Initial seek (join mid-song) | 10-17 seconds |
| Track-to-track transition | Under 1 second |
| Mid-stream rejoin (no seek) | Up to 36 seconds |

Initial MP3 seek error is typically 250-310ms (MP3 keyframe granularity). The PLL smoothly corrects this without audible glitches.

### Steady-State Accuracy

| Metric | Value |
|--------|-------|
| Mean sync error | 14.5ms |
| Median sync error | 12ms |
| 95th percentile error | 36ms |
| Max observed error | 50ms |
| Mean avg2s (PLL input) | 9.2ms |
| Signed bias | -0.2ms (essentially zero) |

### What This Means
- **14.5ms average error** — well below the ~40ms threshold of human audio perception
- **95% of the time within 36ms** — consistently imperceptible sync offset
- **Zero systematic drift** — the PLL tracks the master symmetrically
- **Playback rate stays within 0.7% of normal** (0.9977–1.0049) — completely inaudible
- **Clock offset stable within 4ms** — consistent network latency estimation

## Updating to a New Version

### Quick Update

```bash
cd /home/fpp/fpp-listener-sync
git pull
sudo ./install.sh
```

### If That Doesn't Work (Reset to Latest)

```bash
cd /home/fpp/fpp-listener-sync
git fetch origin
git reset --hard origin/main
sudo ./install.sh
```

### Check Your Version

The version number is shown at the bottom of the listening page: `http://192.168.50.1/listen/`

## Debug Panel and Logging

The listening page has three checkboxes at the bottom:

- **Debug** — Shows a panel with real-time sync data (error, clock offset, effective rate, play latency, etc.)
- **Client Log** — Shows a scrolling log of sync events on the phone screen
- **Server Log** — Sends sync reports to the Pi's log file via WebSocket

All three are **off by default** so they don't affect performance during normal use. Turn them on when you need to diagnose sync issues.

### Debug Panel Fields

| Field | What It Means |
|-------|---------------|
| Transport | `ws` (WebSocket) or `http` (polling fallback) |
| RTT | Round-trip time to the Pi in milliseconds |
| Clock Offset | Estimated clock difference between phone and Pi |
| Error | Current instantaneous sync error in ms (positive = phone is behind FPP) |
| Avg 2s | Rolling 2-second average error — the main PLL input |
| Rate | Current `playbackRate` (near 1.000, adjusted by PLL) |
| Avg Error (all) | Running average of all errors since playback started |
| Effective Rate | Measured actual playback rate |
| Play Latency | Measured `play()` startup delay for this device |
| PLL State | Current PLL phase: `idle`, `calibrating`, or `locked Kp=X.XXX` |

### Server Log on the Pi

When **Server Log** is checked on any client, that client sends sync reports to the Pi. View them with:

```bash
cat /home/fpp/listen-sync/sync.log
```

The log format is:
```
timestamp [client_ip] EVENT fpp=X target=Y local=Z err=Nms avg2s=Nms rate=R eff=E offset=Oms
```

| Field | Meaning |
|-------|---------|
| `fpp` | FPP's reported position (ms) |
| `target` | Extrapolated target position (ms) |
| `local` | Phone's actual audio position (ms) |
| `err` | Instantaneous error (ms) |
| `avg2s` | 2-second rolling average error (ms) — the PLL's main input |
| `rate` | Current `playbackRate` set by PLL |
| `eff` | Measured effective playback rate |
| `offset` | Estimated clock offset (ms) |

Events you'll see:
- `INITIAL_SEEK` — Client seeking to FPP position
- `START` — Audio playback started
- `SYNC` — Periodic sync report (every ~1 second)
- `CORRECTION` — Hard seek correction (only for errors > 2 seconds)
- `STOP` — Track stopped

### Log Management

The sync log **will not fill up your Pi's memory card**:

- **Auto-clear on new track**: Each time a new song starts, the log is cleared and starts fresh
- **5MB size limit**: If the log somehow reaches 5MB, it's rotated (old log renamed to `.log.old`)
- **Log location**: `/home/fpp/listen-sync/sync.log`
- **Only when enabled**: Logs are only written when at least one client has the "Server Log" checkbox checked

To clear the log manually:
```bash
rm /home/fpp/listen-sync/sync.log
```

### WebSocket Server Log

If you need to debug the WebSocket server itself:

```bash
sudo journalctl -u ws-sync -f
```

This shows the Python WebSocket server's output in real-time. Press `Ctrl+C` to stop watching.

## Network Security

The SHOW_AUDIO network is fully isolated from FPP's admin interface and your home network. Three layers of protection:

### 1. No Internet Routing
IP forwarding is disabled on the Pi (`net.ipv4.ip_forward=0`). Phones on SHOW_AUDIO cannot route to your home network or the internet.

### 2. nftables Firewall
A strict firewall on wlan1 only allows the services phones actually need:

| Port | Protocol | Purpose |
|------|----------|---------|
| 67-68 | UDP | DHCP (get an IP address) |
| 53 | UDP/TCP | DNS (wildcard → 192.168.50.1) |
| 80 | TCP | HTTP (Apache — listener page + captive portal) |
| 8080 | TCP | WebSocket (sync server, proxied via /ws) |

Everything else on wlan1 is **rejected** — no SSH, no FPP API, no access to the Pi's other IP addresses. REJECT (not DROP) is used so blocked connections fail instantly instead of timing out, which speeds up captive portal detection on phones.

### 3. Device Isolation
`hostapd` runs with `ap_isolate=1`, which prevents phones from seeing or communicating with each other at the WiFi layer. Audience members can only talk to the Pi, not to each other's devices.

### Why This Matters
The Pi has multiple IP addresses (e.g., `10.x.x.x` on wlan0 and `192.168.50.1` on wlan1). Linux's "weak host model" normally accepts traffic for any IP on any interface. Without the firewall, a phone on SHOW_AUDIO could access FPP's admin UI at the Pi's other IP. The nftables rules prevent this.

## Captive Portal

When a phone joins SHOW_AUDIO, the system triggers the OS captive portal popup ("Sign in to Wi-Fi network") so the listener page opens automatically. Multiple mechanisms work together:

### How It Works

1. **DHCP Option 114 (CAPPORT)** — The DHCP lease includes a Captive Portal API URL (RFC 8910). Modern phones (Android 11+, iOS 14+) fetch this URL and get a JSON response telling them a sign-in page is available.

2. **HTTP Probe Interception** — Phones check specific URLs to test connectivity (e.g., `generate_204` on Android, `hotspot-detect.html` on iOS). Apache's `.htaccess` intercepts these and returns a 302 redirect to `/listen/`, which triggers the captive portal UI.

3. **Wildcard DNS Redirect** — All domain lookups resolve to the Pi via dnsmasq. If a phone opens any website, it hits Apache, which redirects to `/listen/`.

### Captive Portal Behavior

- **First-time visitors**: The captive portal popup appears automatically on most phones. Samsung phones may show a notification that requires a tap.
- **Returning devices**: Android caches captive portal state per network. Phones that have connected before may skip the popup. This is normal OS behavior.
- **Fallback**: The printed QR code sign includes instructions to open `192.168.50.1` in the browser if the popup doesn't appear.

### FPP Cache Override

FPP's Apache config sets `ExpiresDefault "access plus 1 year"` for all responses. The installer adds a `mod_headers` override so the CAPPORT API endpoint (`portal-api.php`) always returns `Cache-Control: private, no-store, max-age=0`.

## File Locations on the Pi

| What | Path |
|------|------|
| Git repo | `/home/fpp/fpp-listener-sync/` |
| Web files (served by Apache) | `/home/fpp/media/www/listen/` |
| Apache symlink | `/opt/fpp/www/listen` → `/home/fpp/media/www/listen/` |
| Music files | `/home/fpp/media/music/` |
| WebSocket server script | `/home/fpp/listen-sync/ws-sync-server.py` |
| Sync log file | `/home/fpp/listen-sync/sync.log` |
| hostapd config | `/home/fpp/listen-sync/hostapd-listener.conf` |
| dnsmasq config | `/etc/dnsmasq.conf` |
| nftables firewall | Applied at runtime by `install.sh` (not persisted to file) |
| Apache captive portal | `/opt/fpp/www/.htaccess` |
| Wi-Fi AP service | `/etc/systemd/system/listener-ap.service` |
| WebSocket service | `/etc/systemd/system/ws-sync.service` |
| wlan1 setup service | `/etc/systemd/system/wlan1-setup.service` |

## Using on Remote FPPs

This plugin works on **both Master and Remote** FPPs!

### Master FPP
- Reads its own playback status
- Serves synced audio to visitors

### Remote FPP
- Also works! Reads its sync status from master
- Serves audio from its own local files
- Each remote creates its own `SHOW_AUDIO` network
- Visitors can connect to the nearest FPP

### Requirements for Remotes
- USB Wi-Fi adapter (wlan1)
- **Audio files must be present locally** in `/home/fpp/media/music/`
- Audio filenames must match sequence names (e.g., `MySong.fseq` → `MySong.mp3`)
- Same installation process as master

### Multi-FPP Setup Options

**Option 1: All FPPs have listener-sync**
- Each FPP broadcasts its own `SHOW_AUDIO` network
- Visitors connect to closest FPP
- Good for large displays with spread-out visitors

**Option 2: Only Master has listener-sync**
- Single `SHOW_AUDIO` network
- All visitors connect to master
- Good for smaller displays

## Visitor Instructions

### Option 1: QR Code (Easiest!)

1. Scan the QR code (generate at `http://192.168.50.1/qrcode.html`)
2. Tap to join **SHOW_AUDIO** Wi-Fi
3. Tap the captive portal popup
4. Tap **Enable Audio**

### Option 2: Manual Connection

1. On your phone, go to Wi-Fi settings
2. Join the network called **SHOW_AUDIO** (no password)
3. A page should pop up automatically. If not, open your browser and go to `192.168.50.1/listen/`
4. Tap **Enable Audio**
5. Audio plays synced to the show!

## QR Code Setup

After installation, generate a Wi-Fi QR code for easy visitor access:

1. Connect to the `SHOW_AUDIO` Wi-Fi network (or access via your home network)
2. Open `http://192.168.50.1/qrcode.html` on your phone or computer
3. Click **Generate QR Code**
4. Click **Download QR Code**
5. Print and display the QR code at your show entrance

Visitors simply scan the code to automatically join the Wi-Fi and access the audio page!

## Uninstall

```bash
cd /home/fpp/fpp-listener-sync
sudo ./uninstall.sh
```

## Troubleshooting

### Common Issues

| Problem | What to Check |
|---------|---------------|
| **SHOW_AUDIO Wi-Fi not visible** | Is the USB Wi-Fi adapter plugged in? Run: `sudo systemctl status listener-ap` |
| **Phone won't get an IP address** | Run: `sudo systemctl status dnsmasq` |
| **No audio playing** | Did you tap "Enable Audio"? Check iPhone ringer switch. Check that MP3 filename matches sequence name. |
| **Audio not syncing** | Enable Debug checkbox — is the WebSocket connected? Check Transport field shows `ws`. |
| **Captive portal not appearing** | Try manually going to `192.168.50.1/listen/` in your browser |
| **WebSocket not connecting** | Run: `sudo systemctl status ws-sync` and check it's running |
| **Can access FPP admin from SHOW_AUDIO** | Firewall not applied. Re-run `sudo ./install.sh` — check for `nftables: wlan1 firewall active` in self-test |
| **Version not updating after deploy** | Hard-refresh the page (pull down to refresh on phone, Ctrl+Shift+R on PC) |

### Checking Service Status

```bash
# Check all services at once
sudo systemctl status listener-ap    # Wi-Fi access point
sudo systemctl status dnsmasq        # DHCP server
sudo systemctl status ws-sync        # WebSocket sync server
sudo systemctl status apache2        # Web server

# Check nftables firewall is active
sudo /usr/sbin/nft list table inet listener_filter
```

### Restarting Everything

If something isn't working and you want to restart all the services:

```bash
cd /home/fpp/fpp-listener-sync
sudo ./install.sh
```

The installer is safe to run multiple times — it will restart everything and re-run the self-test.

## Changelog

### v2.4.0
- **Captive portal overhaul**: DHCP Option 114 (CAPPORT/RFC 8910), portal-api.php endpoint, FPP cache override
- **Firewall**: Changed DROP to REJECT for all blocked wlan1 traffic — phones detect captive portal faster (no 30s timeouts on blocked ports like DNS-over-TLS, HTTPS)
- `.htaccess`: Added `connectivitycheck.android.com`, `msftconnecttest.com` probe hosts
- `portal-api.php`: RFC 8908 Captive Portal API with `JSON_UNESCAPED_SLASHES`, proper `Cache-Control`
- `apache-listener.conf`: Added `mod_headers` override to prevent FPP's 1-year cache on portal API
- Removed SSL VirtualHost (self-signed cert on 443 confused Android captive portal detection)
- DHCP gateway restored (`dhcp-option=3,192.168.50.1`) — required for phones to run captive portal checks
- Print sign includes fallback instruction ("go to 192.168.50.1")
- Tested on FPP v9.4, Samsung S24 Ultra (Android 16), Samsung S21 (Android 15)

### v2.3.5
- Updated all version references, README documentation, LICENSE formatting
- Added network security section to README
- Cleaned up stale file references

### v2.3.4
- **Security fix**: Added nftables firewall to isolate wlan1 (replaces iptables which was not installed on Bookworm)
- Added `dhcp-option=3` (no gateway) to prevent phones from routing to other subnets
- Phones on SHOW_AUDIO can no longer access FPP admin UI, SSH, or other Pi IPs

### v2.3.3
- Removed listen-mdns service (Avahi mDNS broke Android DNS fallback for listen.local)
- listen.local now works correctly via dnsmasq wildcard DNS

### v2.3.2
- Added listen-mdns service for mDNS (reverted in v2.3.3 — caused issues)

### v2.3.1
- Added verbose comments to all code files

### v2.3.0
- README and documentation overhaul
- Log management documented

### v2.2.18
- Tightened baseRate calibration clamp from ±5% to ±1%

### v2.2.17
- Tightened PLL convergence: dead zone 20→5ms, rate interval 2s→1s in steady state

### v2.2.16
- Switched PLL error input from instantaneous error to 2-second rolling average (avg2s)

### v2.2.14–v2.2.15
- Adaptive Kp gain (scales with error magnitude)
- Removed snap-seek at PLL lock (caused overshoot from MP3 keyframe inaccuracy)

### v2.2.0–v2.2.13
- Replaced 5-second hard-seek check with continuous PLL rate correction
- Iterative PLL tuning across many test sessions

### v2.1.0–v2.1.5
- Scheduled-start sync with play-ahead latency compensation
- Three debug checkboxes (Debug, Client Log, Server Log) — all off by default
- Switched to `milliseconds_elapsed` from FPP API for real ms precision

### v2.0.0
- Log-only mode with CSV export for analysis

### v1.7.x–v1.8.x
- WebSocket sync with calibrate-then-apply rate adjustment
- Server-side sync logging

## License

MIT — Built by [Undocumented Engineer](https://github.com/UndocEng)
