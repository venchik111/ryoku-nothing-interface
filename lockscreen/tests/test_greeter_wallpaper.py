"""Exercise wallpaper persistence with real images and a local Ryogami socket."""
import importlib.util
import json
from pathlib import Path
import socket
import tempfile
import threading
import unittest

from PIL import Image

SPEC = importlib.util.spec_from_file_location("greeter_wallpaper", Path(__file__).parents[1] / "nothing-interface/bin/greeter-wallpaper.py")
sync = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(sync)


class WallpaperTests(unittest.TestCase):
    def test_replacement_and_corrupt_source_preserve_valid_cache(self):
        with tempfile.TemporaryDirectory() as folder:
            source = Path(folder) / "source.png"
            destination = Path(folder) / "current.png"
            Image.new("RGBA", (1920, 1080), (80, 90, 100, 255)).save(source)
            sync.publish(source, destination)
            with Image.open(destination) as image:
                self.assertEqual(image.size, (1920, 1080))
                self.assertEqual(image.mode, "RGB")
            self.assertEqual(destination.stat().st_mode & 0o777, 0o644)
            saved = destination.read_bytes()
            source.write_bytes(b"not an image")
            with self.assertRaises(OSError):
                sync.publish(source, destination)
            self.assertEqual(destination.read_bytes(), saved)
            Image.new("RGB", (1920, 1080), (150, 150, 160)).save(source)
            sync.publish(source, destination)
            with Image.open(destination) as image:
                self.assertEqual(image.getpixel((0, 0)), (150, 150, 160))
            self.assertFalse(list(Path(folder).glob(".background-*")))

    def test_primary_output_then_default(self):
        frame = {"default": {"path": "default"}, "outputs": {"DP-1": {"path": "primary"}}}
        self.assertEqual(sync.wallpaper_entry(frame, "DP-1")["path"], "primary")
        self.assertEqual(sync.wallpaper_entry(frame, "disconnected")["path"], "default")
        self.assertEqual(sync.wallpaper_entry({"default": {}, "outputs": frame["outputs"]})["path"], "primary")

    def test_socket_snapshot_remains_after_daemon_exit(self):
        with tempfile.TemporaryDirectory() as folder:
            source = Path(folder) / "source.png"
            destination = Path(folder) / "current.png"
            socket_path = Path(folder) / "ryogami.sock"
            Image.new("RGB", (32, 18), "#24262B").save(source)
            with socket.socket(socket.AF_UNIX) as server:
                server.bind(str(socket_path))
                server.listen(1)
                server.settimeout(3)

                def send_snapshot():
                    connection, _ = server.accept()
                    with connection:
                        self.assertEqual(connection.recv(1024), b"subscribe wallpaper\n")
                        connection.sendall((json.dumps({"default": {"path": str(source)}, "outputs": {}}) + "\n").encode())

                sender = threading.Thread(target=send_snapshot)
                sender.start()
                sync.synchronize(socket_path, destination, once=True)
                sender.join(timeout=3)
                self.assertFalse(sender.is_alive())
            with Image.open(destination) as image:
                self.assertEqual(image.getpixel((0, 0)), (36, 38, 43))


if __name__ == "__main__":
    unittest.main()
