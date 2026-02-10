
# FPP Listener Sync



**Stream synced show audio to visitor phones — no app, no FM transmitter, no speakers.**



Visitors connect to an open Wi-Fi AP, open a URL, and hear show audio synced to the currently playing FPP sequence — right from their phone browser.



## How It Works



1. FPP plays sequences (`.fseq`) with matching `.mp3` files as normal

2. A USB Wi-Fi adapter broadcasts an open AP (`SHOW_AUDIO`)

3. Visitors join the AP and open **`listen.local/listen/`** (or `192.168.50.1/listen/`)

4. The browser downloads the MP3 and syncs playback to FPP's position

5. No app install required — works in Safari, Chrome, Firefox



## Important

**Music Licensing**: You are responsible for ensuring you have the proper rights and permissions to broadcast any music used with this system. This includes public performance licenses (ASCAP, BMI, SESAC, etc.) as required by your local laws. Parse this code repo. Modify and use at your own risk. 



## Requirements



- FPP v9.x on Raspberry Pi (tested on v9.3)

- USB Wi-Fi adapter (nl80211-compatible, e.g. rtl8192cu)

- Apache + PHP (included in standard FPP images)

- `.fseq` and audio files must share the same base filename (e.g. `MySong.fseq` and `MySong.mp3`)

- Supported audio formats: MP3, M4A, AAC, OGG, WAV (MP3 preferred for best compatibility)



## Getting Started

### 1. Enable SSH on FPP

1. Open FPP web interface (usually `http://fpp.local` or your Pi's IP)
2. Click the **Help** menu (top right)
3. Select **SSH Access**
4. Enable SSH and click **Save**

### 2. Connect via SSH

**From Windows:**
- Use PuTTY or Windows Terminal
- Host: `fpp.local` or your FPP IP address
- Port: 22

**From Mac/Linux:**
```bash
ssh fpp@fpp.local
# Or use IP: ssh fpp@192.168.x.x
```

**Default credentials:**
- Username: `fpp`
- Password: `falcon`

## Install

```bash

cd /home/fpp

git clone https://github.com/UndocEng/fpp-listener-sync.git

cd fpp-listener-sync

sudo ./install.sh

```



## Update

To update to the latest version:

```bash
cd /home/fpp/fpp-listener-sync
git pull
sudo ./install.sh
```

The installer will:
- Update all web files to the latest version
- Update system configurations if needed
- Restart services automatically
- Run self-tests to verify everything works

### Check Current Version

View your installed version at: **`listen.local/listen/`** or `192.168.50.1/listen/` (shown at bottom of page)

### Troubleshooting Updates

If `git pull` shows conflicts or errors:

```bash
cd /home/fpp/fpp-listener-sync

# Discard local changes and reset to latest
git fetch origin
git reset --hard origin/Update_uninstall.sh

# Run installer
sudo ./install.sh
```

### After Update

- Check that SHOW_AUDIO WiFi is broadcasting
- Verify version number updated on listening page
- Test that audio sync still works

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

## Uninstall

```bash

cd /home/fpp/fpp-listener-sync

sudo ./uninstall.sh

```

## Access URLs

After connecting to the **SHOW_AUDIO** WiFi network:

- **Listening Page**: `listen.local/listen/` (easy to remember!) or `192.168.50.1/listen/`
- **QR Code Generator**: `listen.local/qrcode.html` or `192.168.50.1/qrcode.html`
- **Print Sign**: `listen.local/print-sign.html` or `192.168.50.1/print-sign.html`

💡 **Tip**: Share **`listen.local/listen/`** with visitors — it's much easier to remember than an IP address!

## Visitor Instructions

### Option 1: QR Code (Easiest!)

1. Scan the QR code (generate at **http://192.168.50.1/qrcode.html**)

2. Tap to join **SHOW_AUDIO** Wi-Fi

3. Tap the captive portal popup

4. Tap **Enable Audio**

### Option 2: Manual Connection

1. Join Wi-Fi: **SHOW_AUDIO** (no password)

2. Open: **`listen.local/listen/`** (or `192.168.50.1/listen/`)

3. Tap: **Enable Audio**

4. Audio plays synced to the show



## QR Code Setup

After installation, generate a Wi-Fi QR code for easy visitor access:

1. Open **http://192.168.50.1/qrcode.html** on your phone/computer

2. Click **Generate QR Code**

3. Click **Download QR Code**

4. Print and display the QR code at your show entrance

Visitors simply scan the code to automatically join the Wi-Fi and access the audio page!

## Architecture



- Phone downloads full MP3, polls `status.php` at 4Hz for current position

- Server timestamp enables sub-second smoothing between FPP's 1-second updates

- Gentle playback rate nudging (0.997x-1.003x) keeps sync under 100ms

- Hard seek only when error exceeds 1 second

- Captive portal automatically redirects visitors to the audio page

- Listener network is fully isolated from show network (no IP forwarding)



## Troubleshooting



- **SHOW_AUDIO not visible:** `sudo systemctl status listener-ap`

- **No DHCP lease:** `sudo systemctl status dnsmasq`

- **No audio:** Tap Enable Audio, check ringer switch (iPhone)

- **Choppy audio:** Check debug panel, try different Wi-Fi channel in config



## License



MIT — Built by [Undocumented Engineer](https://github.com/UndocEng)

