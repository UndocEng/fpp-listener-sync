<?php
/**
 * status.php — HTTP Fallback Endpoint for FPP Listener Sync
 * ==========================================================
 *
 * This is the fallback transport when WebSocket is unavailable.
 * The client polls this endpoint every 250ms via fetch().
 *
 * What it does:
 *   1. Calls the FPP local REST API (http://127.0.0.1/api/fppd/status)
 *   2. Extracts playback state (playing/stopped/paused), track name, position
 *   3. Returns JSON in the same format as the WebSocket broadcast
 *
 * Clock offset support:
 *   Captures timestamps before and after the FPP API call. The midpoint
 *   (server_ms) is the best estimate of when pos_ms was valid. The client
 *   uses server_ms + its own request timing to compute clock offset, just
 *   like the WebSocket ping/pong mechanism.
 *
 * IMPORTANT: Uses round() instead of intval() for epoch-ms timestamps.
 *   On Pi 3B (32-bit PHP), intval() overflows at 2^31 = 2,147,483,647,
 *   but epoch-ms values are ~1,700,000,000,000. round() returns a float
 *   which handles this correctly.
 */

header('Content-Type: application/json');
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Pragma: no-cache');


// Make a GET request and parse the JSON response. Returns null on failure.
// 1-second timeout prevents blocking if FPP is unresponsive.
function http_get_json($url) {

  $ctx = stream_context_create(['http' => ['timeout' => 1.0]]);

  $raw = @file_get_contents($url, false, $ctx);

  if ($raw === false) return null;

  $js = json_decode($raw, true);

  if (!is_array($js)) return null;

  return $js;

}


// Extract filename without extension. e.g., "MyShow.fseq" -> "MyShow"
// Used to match FPP sequence names to audio filenames.
function basename_noext($path) {

  if (!$path) return "";

  $p = basename($path);

  return preg_replace('/\.[^.]+$/', '', $p);

}


$srcUrl = "http://127.0.0.1/api/fppd/status";

// Capture timing around FPP API call for clock offset estimation.
// The midpoint of start/end is the best estimate of when pos_ms was valid.
// Use round() not intval() — intval() overflows on 32-bit PHP (Pi 3B).
$server_ms_start = round(microtime(true) * 1000);
$src = http_get_json($srcUrl);
$server_ms_end = round(microtime(true) * 1000);
$server_ms = round(($server_ms_start + $server_ms_end) / 2);


if ($src === null) {

  echo json_encode([

    "state" => "stop",

    "base" => "",

    "pos_ms" => 0,

    "mp3_url" => "",

    "server_ms" => $server_ms,

    "debug" => "Cannot read $srcUrl"

  ]);

  exit;

}


// Parse FPP status — prefer status_name (string), fall back to status (integer)
$status = isset($src["status"]) ? intval($src["status"]) : -1;

$status_name = isset($src["status_name"]) ? strval($src["status_name"]) : "";


$state = "stop";

$sn = strtolower($status_name);

if ($sn === "playing" || $sn === "play") $state = "play";

else if ($sn === "paused" || $sn === "pause") $state = "pause";

else if ($sn === "idle" || $sn === "stopped" || $sn === "stop") $state = "stop";

else {

  if ($status === 1) $state = "play";

  else if ($status === 2) $state = "pause";

  else $state = "stop";

}


// Extract sequence name and strip extension to get the base name
// e.g., "MyShow.fseq" -> "MyShow"
$seq = isset($src["current_sequence"]) ? strval($src["current_sequence"]) : "";

$base = basename_noext($seq);


// Get playback position in milliseconds.
// IMPORTANT: Use milliseconds_elapsed, NOT seconds_played.
// seconds_played is whole-second only (0, 1, 2, ...) — useless for ms-precision sync.
// milliseconds_elapsed gives true ms precision from FPP's internal clock.
$pos_ms = isset($src["milliseconds_elapsed"]) ? round($src["milliseconds_elapsed"]) : 0;


// Find matching audio file — check for supported formats in priority order.
// FPP stores music in /home/fpp/media/music/, served at /music/ by Apache symlink.
$audio_url = "";
if ($base !== "") {
  $music_dir = "/home/fpp/media/music";
  $formats = ["mp3", "m4a", "mp4", "aac", "ogg", "wav"];

  foreach ($formats as $ext) {
    if (file_exists("$music_dir/$base.$ext")) {
      $audio_url = "/music/" . rawurlencode($base) . ".$ext";
      break;
    }
  }
}

$mp3_url = $audio_url; // Variable name kept for client-side compatibility


// Return JSON — matches the WebSocket broadcast format exactly so the client's
// sync() function can process both identically.
echo json_encode([

  "state" => $state,

  "base" => $base,

  "pos_ms" => $pos_ms,

  "mp3_url" => $mp3_url,

  "server_ms" => $server_ms,

  "server_ms_start" => $server_ms_start,

  "server_ms_end" => $server_ms_end,


  "debug_src" => $srcUrl,

  "debug_status" => $status,

  "debug_status_name" => $status_name,

  "debug_seq" => $seq,

  "debug_milliseconds_elapsed" => $pos_ms

]);
