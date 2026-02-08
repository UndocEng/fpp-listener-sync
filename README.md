
# FPP Listener Sync



**Stream synced show audio to visitor phones — no app, no FM transmitter, no speakers.**



Visitors connect to an open Wi-Fi AP, open a URL, and hear show audio synced to the currently playing FPP sequence — right from their phone browser.



## How It Works



1. FPP plays sequences (`.fseq`) with matching `.mp3` files as normal

2. A USB Wi-Fi adapter broadcasts an open AP (`SHOW_AUDIO`)

3. Visitors join the AP and open `http://192.168.50.1/listen/`

4. The browser downloads the MP3 and syncs playback to FPP's position

5. No app install required — works in Safari, Chrome, Firefox



## Requirements



- FPP v9.x on Raspberry Pi (tested on v9.3)

- USB Wi-Fi adapter (nl80211-compatible, e.g. rtl8192cu)

- Apache + PHP (included in standard FPP images)

- `.fseq` and `.mp3` files must share the same base filename (e.g. `MySong.fseq` and `MySong.mp3`)



## Install

```bash

cd /home/fpp

git clone https://github.com/UndocEng/fpp-listener-sync.git

cd fpp-listener-sync

sudo ./install.sh

```



## Update

```bash

cd /home/fpp/fpp-listener-sync

git pull

sudo ./install.sh

```



## Uninstall

```bash

cd /home/fpp/fpp-listener-sync

sudo ./uninstall.sh

```



## Visitor Instructions



1. Join Wi-Fi: **SHOW_AUDIO** (no password)

2. Open: **http://192.168.50.1/listen/**

3. Tap: **Enable Audio**

4. Audio plays synced to the show



## Architecture



- Phone downloads full MP3, polls `status.php` at 4Hz for current position

- Server timestamp enables sub-second smoothing between FPP's 1-second updates

- Gentle playback rate nudging (0.997x-1.003x) keeps sync under 100ms

- Hard seek only when error exceeds 1 second

- Listener network is fully isolated from show network (no IP forwarding)



## Troubleshooting



- **SHOW_AUDIO not visible:** `sudo systemctl status listener-ap`

- **No DHCP lease:** `sudo systemctl status dnsmasq`

- **No audio:** Tap Enable Audio, check ringer switch (iPhone)

- **Choppy audio:** Check debug panel, try different Wi-Fi channel in config



## License



MIT — Built by [Undocumented Engineer](https://github.com/UndocEng)

