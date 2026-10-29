import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parent
QML = shutil.which('qml6') or shutil.which('qml') or '/usr/lib/qt6/bin/qml'


@unittest.skipUnless(Path(QML).is_file(), 'Qt 6 QML runtime not installed')
class GreeterQmlTests(unittest.TestCase):
    def test_saved_background_sessions_and_confirmed_power(self):
        with tempfile.TemporaryDirectory() as folder:
            background = Path(folder) / 'wallpaper.png'
            Image.new('RGB', (1920, 1080), '#383c43').save(background)
            for mode in ('greeter', 'lockscreen', 'session-menu', 'power-confirm'):
                with self.subTest(mode=mode):
                    output = Path(folder) / (mode + '.png')
                    env = dict(os.environ, LANG='ru_RU.UTF-8', LC_ALL='ru_RU.UTF-8',
                               QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
                               QT_QUICK_CONTROLS_STYLE='Basic', QML_XHR_ALLOW_FILE_READ='1',
                               QML_IMPORT_PATH=str(ROOT / 'imports'),
                               QT_FORCE_STDERR_LOGGING='1', QT_LOGGING_TO_CONSOLE='1',
                               QT_LOGGING_RULES='*.debug=false;qml.debug=true;qml.warning=true;qml.critical=true')
                    result = subprocess.run([
                        QML, str(ROOT / 'verify-greeter.qml'), '--',
                        '--mode', mode, '--background', background.as_uri(), '--output', str(output),
                    ], env=env, capture_output=True, text=True, timeout=12)
                    log = result.stdout + result.stderr
                    self.assertEqual(result.returncode, 0, log)
                    self.assertIn('PASS: wallpaper, session selection, password errors, power confirmation and capabilities', log)
                    with Image.open(output) as preview:
                        self.assertEqual(preview.size, (1920, 1080))
