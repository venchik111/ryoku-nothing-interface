import hashlib
import json
from pathlib import Path
import shutil
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1] / 'nothing-interface'


class ManifestTests(unittest.TestCase):
    def test_package_integrity_and_installation(self):
        manifest = json.loads((ROOT / 'manifest.json').read_text())
        listed = set()
        destinations = set()
        with tempfile.TemporaryDirectory() as directory:
            install = Path(directory)
            for entry in manifest['files']:
                with self.subTest(source=entry['source']):
                    relative = Path(entry['source'])
                    destination = Path(entry['destination'])
                    self.assertFalse(relative.is_absolute() or '..' in relative.parts)
                    self.assertFalse(destination.is_absolute() or '..' in destination.parts)
                    self.assertNotIn(str(relative), listed)
                    self.assertNotIn(str(destination), destinations)
                    listed.add(str(relative))
                    destinations.add(str(destination))
                    source = ROOT / relative
                    data = source.read_bytes()
                    self.assertEqual(len(data), entry['size'])
                    self.assertEqual(hashlib.sha256(data).hexdigest(), entry['sha256'])
                    if entry['install']:
                        target = install / destination
                        target.parent.mkdir(parents=True, exist_ok=True)
                        shutil.copyfile(source, target)
                        target.chmod(int(entry['mode'], 8))
                        self.assertEqual(target.read_bytes(), data)
            required = {
                str(path.relative_to(ROOT)) for path in ROOT.rglob('*')
                if path.is_file() and path.name != 'manifest.json' and '__pycache__' not in path.parts
            }
            self.assertEqual(listed, required)
            self.assertIn('Version=' + manifest['version'], (install / 'metadata.desktop').read_text())
