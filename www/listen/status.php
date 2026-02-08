<?php

header('Content-Type: application/json');


function http_get_json($url) {

  $ctx = stream_context_create(['http' => ['timeout' => 1.0]]);

  $raw = @file_get_contents($url, false, $ctx);

  if ($raw === false) return null;

  $js = json_decode($raw, true);

  if (!is_array($js)) return null;

  return $js;

}


function basename_noext($path) {

  if (!$path) return "";

  $p = basename($path);

  return preg_replace('/\.[^.]+$/', '', $p);

}


$srcUrl = "http://127.0.0.1/api/fppd/status";

$src = http_get_json($srcUrl);


$server_ms = intval(microtime(true) * 1000);


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


$seq = isset($src["current_sequence"]) ? strval($src["current_sequence"]) : "";

$base = basename_noext($seq);


$sec_played = 0.0;

if (isset($src["seconds_played"])) $sec_played = floatval($src["seconds_played"]);

$pos_ms = intval($sec_played * 1000.0);


$mp3_url = ($base !== "") ? ("/music/" . rawurlencode($base) . ".mp3") : "";


echo json_encode([

  "state" => $state,

  "base" => $base,

  "pos_ms" => $pos_ms,

  "mp3_url" => $mp3_url,

  "server_ms" => $server_ms,


  "debug_src" => $srcUrl,

  "debug_status" => $status,

  "debug_status_name" => $status_name,

  "debug_seq" => $seq,

  "debug_seconds_played" => $sec_played

]);
