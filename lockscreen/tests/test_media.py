import contextlib
import io
import json
from pathlib import Path
import runpy
import subprocess
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / 'nothing-interface/bin/media.py'


class MediaTests(unittest.TestCase):
    def read_media(self, players, position='12', length='60000000'):
        selected = []

        def run(argv, **kwargs):
            if argv == ['playerctl', '-l']:
                value = '\n'.join(players)
            else:
                self.assertEqual(argv[:2], ['playerctl', '-p'])
                player, command = argv[2], argv[3:]
                selected.append((player, command))
                values = {
                    ('status',): players[player],
                    ('position',): position,
                    ('metadata', '--format', '{{title}}\n{{artist}}'): player + ' title\nartist',
                    ('metadata', '--format', '{{mpris:artUrl}}'): 'file:///mock.png',
                    ('metadata', '--format', '{{mpris:length}}'): length,
                }
                value = values[tuple(command)]
            return subprocess.CompletedProcess(argv, 0, value)

        output = io.StringIO()
        with patch('subprocess.run', run), contextlib.redirect_stdout(output):
            try:
                runpy.run_path(str(SCRIPT), run_name='__main__')
            except SystemExit as error:
                self.assertEqual(error.code, 0)
        return json.loads(output.getvalue()), selected

    def test_selection_and_metadata_use_same_player(self):
        cases = [
            ({'browser': 'Stopped', 'ryotunes': 'Playing'}, 'ryotunes'),
            ({'browser': 'Paused', 'ryotunes': 'Playing'}, 'ryotunes'),
            ({'browser': 'Stopped', 'ryotunes': 'Paused'}, 'ryotunes'),
            ({'browser': 'Stopped', 'ryotunes': 'Stopped'}, 'browser'),
            ({'browser': 'Playing', 'ryotunes': 'Playing'}, 'browser'),
        ]
        for players, expected in cases:
            with self.subTest(players=players):
                data, calls = self.read_media(players)
                self.assertEqual(data['player'], expected)
                self.assertEqual(data['title'], expected + ' title')
                self.assertEqual(data['playing'], players[expected] == 'Playing')
                self.assertEqual(data['available'], players[expected] in ('Playing', 'Paused'))
                self.assertEqual((data['position'], data['length']), (12, 60))
                for player, command in calls:
                    if command != ['status']:
                        self.assertEqual(player, expected)

    def test_no_players(self):
        data, calls = self.read_media({})
        self.assertEqual(data['player'], '')
        self.assertFalse(data['available'])
        self.assertFalse(data['playing'])
        self.assertEqual(calls, [])

    def test_missing_playerctl_and_timeout(self):
        for error in (FileNotFoundError(), subprocess.TimeoutExpired('playerctl', 2)):
            with self.subTest(error=type(error).__name__):
                output = io.StringIO()
                with patch('subprocess.run', side_effect=error), contextlib.redirect_stdout(output):
                    with self.assertRaises(SystemExit) as stopped:
                        runpy.run_path(str(SCRIPT), run_name='__main__')
                self.assertEqual(stopped.exception.code, 0)
                self.assertFalse(json.loads(output.getvalue())['available'])

    def test_invalid_position_and_length(self):
        for value in ('', 'invalid', '-1'):
            with self.subTest(value=value):
                data, _ = self.read_media({'ryotunes': 'Playing'}, value, value)
                self.assertEqual((data['position'], data['length']), (0, 0))
