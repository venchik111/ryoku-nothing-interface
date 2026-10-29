import json
import os
from pathlib import Path
import shutil
import subprocess
import unittest


ROOT = Path(__file__).resolve().parent
QML = shutil.which('qml6') or shutil.which('qml') or '/usr/lib/qt6/bin/qml'


@unittest.skipUnless(Path(QML).is_file(), 'Qt 6 QML runtime not installed')
class QmlTests(unittest.TestCase):
    def test_locales_focus_login_and_playback(self):
        for locale in ('es_ES', 'ru_RU', 'ja_JP', 'en_US', 'pt_BR', 'ar_SA'):
            with self.subTest(locale=locale):
                env = dict(os.environ, LANG=locale + '.UTF-8', LC_ALL=locale + '.UTF-8',
                           QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
                           QT_QUICK_CONTROLS_STYLE='Basic',
                           QML_XHR_ALLOW_FILE_READ='1', QML_IMPORT_PATH=str(ROOT / 'imports'),
                           QT_FORCE_STDERR_LOGGING='1', QT_LOGGING_TO_CONSOLE='1',
                           QT_LOGGING_RULES='*.debug=false;qml.debug=true;qml.warning=true;qml.critical=true')
                result = subprocess.run([QML, str(ROOT / 'verify-lockscreen.qml')],
                                        env=env, capture_output=True, text=True, timeout=8)
                log = result.stdout + result.stderr
                self.assertEqual(result.returncode, 0, log)
                self.assertIn('PASS locale, focus, login reset and targeted playback', log)
                language = locale if locale == 'pt_BR' else locale.split('_')[0]
                catalogue = Path('/usr/share/ryoku/i18n') / (language + '.json')
                expected = 'BATTERY'
                if catalogue.is_file():
                    expected = json.loads(catalogue.read_text()).get('BATTERY', expected)
                self.assertIn('BATTERY=' + expected, log)
