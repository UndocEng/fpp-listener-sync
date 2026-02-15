#!/usr/bin/env python3
"""
FPP WebSocket Sync Beacon v1.8.1
Polls FPP API every 100ms, broadcasts position to all WebSocket clients.
Provides ping/pong for RTT-based clock offset estimation.
Logs client sync reports to /home/fpp/listen-sync/sync.log.
"""

import asyncio
import json
import time
import logging
import urllib.request
import urllib.parse
from pathlib import Path
from datetime import datetime

try:
    import websockets
except ImportError:
    print("ERROR: 'websockets' package not found.")
    print("Install with: pip3 install websockets")
    raise SystemExit(1)

# --- Configuration ---
FPP_API_URL = "http://127.0.0.1/api/fppd/status"
WS_HOST = "0.0.0.0"
WS_PORT = 8080
POLL_INTERVAL_MS = 100
MUSIC_DIR = Path("/home/fpp/media/music")
AUDIO_FORMATS = ["mp3", "m4a", "mp4", "aac", "ogg", "wav"]
SYNC_LOG_PATH = Path("/home/fpp/listen-sync/sync.log")
SYNC_LOG_MAX_BYTES = 5 * 1024 * 1024  # 5 MB max, then rotate

logger = logging.getLogger("ws-sync")

# --- Shared State ---
clients = set()
current_state = {}


def write_sync_log(client_ip, data):
    """Append a client sync report to the sync log file.
    Auto-clears log on TRACK event (new song = fresh log)."""
    try:
        event = data.get("event", "?")

        # Auto-clear log on new track
        if event == "TRACK":
            if SYNC_LOG_PATH.exists():
                SYNC_LOG_PATH.unlink()
            track = data.get("track", "")
            now = datetime.now()
            ts = now.strftime("%Y-%m-%d %H:%M:%S.") + f"{now.microsecond // 1000:03d}"
            with open(SYNC_LOG_PATH, "a") as f:
                f.write(f"--- NEW TRACK: {track} @ {ts} [{client_ip}] ---\n")
            return

        # Rotate if too large
        if SYNC_LOG_PATH.exists() and SYNC_LOG_PATH.stat().st_size > SYNC_LOG_MAX_BYTES:
            old = SYNC_LOG_PATH.with_suffix(".log.old")
            if old.exists():
                old.unlink()
            SYNC_LOG_PATH.rename(old)

        now = datetime.now()
        ts = now.strftime("%Y-%m-%d %H:%M:%S.") + f"{now.microsecond // 1000:03d}"
        fpp = data.get("fpp", 0)
        target = data.get("target", 0)
        local = data.get("local", 0)
        err = data.get("err", 0)
        rate = data.get("rate", 1.0)
        eff = data.get("eff", 0)
        offset = data.get("offset", 0)
        avg2s = data.get("avg2s", 0)
        track = data.get("track", "")
        line = f"{ts} [{client_ip}] {event:12s} fpp={fpp:>7d} target={target:>7d} local={local:>7d} err={err:>5d}ms avg2s={avg2s:>5d}ms rate={rate:.4f} eff={eff:.3f} offset={offset:>4d}ms\n"

        with open(SYNC_LOG_PATH, "a") as f:
            f.write(line)
    except Exception as e:
        logger.debug(f"Sync log write error: {e}")


def basename_noext(path):
    """Extract filename without extension."""
    if not path:
        return ""
    return Path(path).stem


_audio_cache = {}

def find_audio_file(base):
    """Find matching audio file, return URL path or empty string. Cached per base name."""
    if not base:
        return ""
    if base in _audio_cache:
        return _audio_cache[base]
    for ext in AUDIO_FORMATS:
        if (MUSIC_DIR / f"{base}.{ext}").exists():
            url = f"/music/{urllib.parse.quote(base)}.{ext}"
            _audio_cache[base] = url
            return url
    _audio_cache[base] = ""
    return ""


def fetch_fpp_status():
    """Synchronous FPP API call (runs in thread)."""
    try:
        req = urllib.request.Request(FPP_API_URL)
        with urllib.request.urlopen(req, timeout=1.0) as resp:
            return json.loads(resp.read())
    except Exception:
        return None


def parse_fpp_state(src, server_ms):
    """Convert raw FPP API response to broadcast format. Returns None on API failure."""
    if src is None:
        return None

    status_name = str(src.get("status_name", "")).lower()
    status_int = int(src.get("status", -1))

    if status_name in ("playing", "play"):
        state = "play"
    elif status_name in ("paused", "pause"):
        state = "pause"
    elif status_name in ("idle", "stopped", "stop"):
        state = "stop"
    elif status_int == 1:
        state = "play"
    elif status_int == 2:
        state = "pause"
    else:
        state = "stop"

    seq = str(src.get("current_sequence", ""))
    base = basename_noext(seq)
    pos_ms = int(src.get("milliseconds_elapsed", 0))
    mp3_url = find_audio_file(base)

    return {
        "state": state,
        "base": base,
        "pos_ms": pos_ms,
        "mp3_url": mp3_url,
        "server_ms": server_ms
    }


async def broadcast(message):
    """Send message to all connected clients. Remove dead ones."""
    if not clients:
        return
    dead = set()
    for ws in clients:
        try:
            await ws.send(message)
        except websockets.ConnectionClosed:
            dead.add(ws)
        except Exception:
            dead.add(ws)
    clients.difference_update(dead)


async def fpp_poll_loop():
    """Poll FPP API every POLL_INTERVAL_MS, broadcast to all clients."""
    global current_state
    while True:
        t_before = time.time()
        src = await asyncio.to_thread(fetch_fpp_status)
        t_after = time.time()
        server_ms = int(((t_before + t_after) / 2) * 1000)

        new_state = parse_fpp_state(src, server_ms)
        if new_state is not None:
            current_state = new_state
        elif current_state:
            # API hiccup: keep last known state, just update timestamp
            current_state["server_ms"] = server_ms
        if current_state:
            await broadcast(json.dumps(current_state))

        elapsed = time.time() - t_before
        sleep_s = max(0.01, (POLL_INTERVAL_MS / 1000.0) - elapsed)
        await asyncio.sleep(sleep_s)


async def handle_client(websocket, path=None):
    """Handle a single WebSocket client connection."""
    clients.add(websocket)
    remote = websocket.remote_address
    logger.info(f"Client connected: {remote} (total: {len(clients)})")

    try:
        # Send current state immediately on connect
        if current_state:
            await websocket.send(json.dumps(current_state))

        # Listen for client messages (ping for RTT, report for sync logging)
        client_ip = remote[0] if remote else "unknown"
        async for message in websocket:
            try:
                data = json.loads(message)
                msg_type = data.get("type")
                if msg_type == "ping":
                    await websocket.send(json.dumps({
                        "type": "pong",
                        "client_ts": data.get("client_ts", 0),
                        "server_ts": int(time.time() * 1000)
                    }))
                elif msg_type == "report":
                    write_sync_log(client_ip, data)
            except json.JSONDecodeError:
                pass
    except websockets.ConnectionClosed:
        pass
    finally:
        clients.discard(websocket)
        logger.info(f"Client disconnected: {remote} (total: {len(clients)})")


async def main():
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(name)s] %(levelname)s: %(message)s"
    )

    logger.info(f"Starting WebSocket sync beacon on port {WS_PORT}")
    logger.info(f"Polling FPP API every {POLL_INTERVAL_MS}ms")
    logger.info(f"Client sync log: {SYNC_LOG_PATH}")

    # Write separator to sync log on start
    try:
        SYNC_LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
        with open(SYNC_LOG_PATH, "a") as f:
            f.write(f"\n--- ws-sync started {datetime.now().isoformat()} ---\n")
    except Exception:
        pass

    poll_task = asyncio.create_task(fpp_poll_loop())

    async with websockets.serve(
        handle_client, WS_HOST, WS_PORT,
        ping_interval=20,
        ping_timeout=30,
        max_size=4096,
        compression=None
    ):
        logger.info(f"WebSocket server listening on ws://{WS_HOST}:{WS_PORT}")
        await poll_task


if __name__ == "__main__":
    asyncio.run(main())
