#!/usr/bin/env python3
"""Read local MPRIS metadata through playerctl, preferring the playing player."""

import json
import subprocess


def run(argv):
    try:
        return subprocess.run(
            argv, capture_output=True, text=True, timeout=2, check=False,
        ).stdout.strip()
    except (OSError, subprocess.TimeoutExpired):
        return ''


players = run(['playerctl', '-l']).splitlines()
if not players:
    print(json.dumps({
        'player': '', 'playing': False, 'available': False, 'title': '', 'artist': '',
        'artUrl': '', 'position': 0.0, 'length': 0.0
    }, ensure_ascii=False))
    raise SystemExit(0)

active_player = None
for p in players:
    status = run(['playerctl', '-p', p, 'status'])
    if status == 'Playing':
        active_player = p
        break

if not active_player:
    for p in players:
        status = run(['playerctl', '-p', p, 'status'])
        if status == 'Paused':
            active_player = p
            break

if not active_player:
    active_player = players[0]

player_prefix = ['playerctl', '-p', active_player]
status = run(player_prefix + ['status'])
metadata = run(player_prefix + ['metadata', '--format', '{{title}}\n{{artist}}'])
art_url = run(player_prefix + ['metadata', '--format', '{{mpris:artUrl}}'])
lines = metadata.splitlines()

try:
    position = max(0.0, float(run(player_prefix + ['position'])))
except ValueError:
    position = 0.0
try:
    length = max(0.0, float(run(player_prefix + ['metadata', '--format', '{{mpris:length}}'])) / 1_000_000)
except ValueError:
    length = 0.0

print(json.dumps({
    'player': active_player,
    'playing': status == 'Playing',
    'available': status in ('Playing', 'Paused'),
    'title': lines[0][:80] if lines else '',
    'artist': lines[1][:60] if len(lines) > 1 else '',
    'artUrl': art_url if status in ('Playing', 'Paused') else '',
    'position': position,
    'length': length,
}, ensure_ascii=False))
