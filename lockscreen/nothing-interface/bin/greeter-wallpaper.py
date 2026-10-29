#!/usr/bin/env python3
"""Publish the latest Ryogami image for SDDM without access to the user's home."""

import argparse
import json
import os
from pathlib import Path
import socket
import tempfile
import time

from PIL import Image, ImageOps

BACKGROUND = Path("/var/lib/ryoku/nothing-interface/background/current.png")
MAX_FRAME = 1024 * 1024


def wallpaper_entry(frame, primary=""):
    outputs = frame.get("outputs") or {}
    if primary and outputs.get(primary, {}).get("path"):
        return outputs[primary]
    default = frame.get("default") or {}
    if default.get("path"):
        return default
    return next((entry for entry in outputs.values() if entry.get("path")), {})


def publish(source, destination):
    """Decode to a metadata-free PNG, then replace the previous image atomically."""
    source = Path(source)
    destination = Path(destination)
    with Image.open(source) as original:
        image = ImageOps.exif_transpose(original)
        image.thumbnail((4096, 4096), Image.Resampling.LANCZOS)
        if "A" in image.getbands():
            rgba = image.convert("RGBA")
            image = Image.new("RGB", rgba.size, "#24262B")
            image.paste(rgba, mask=rgba.getchannel("A"))
        else:
            image = image.convert("RGB")
        image.info.clear()
        # The directory is prepared once by the privileged setup helper. This
        # daemon is always run as the desktop user, never as root.
        descriptor, temporary = tempfile.mkstemp(prefix=".background-", dir=destination.parent)
        try:
            with os.fdopen(descriptor, "wb") as stream:
                image.save(stream, format="PNG")
                stream.flush()
                os.fsync(stream.fileno())
                os.fchmod(stream.fileno(), 0o644)
            os.replace(temporary, destination)
            directory = os.open(destination.parent, os.O_RDONLY | os.O_DIRECTORY)
            try:
                os.fsync(directory)
            finally:
                os.close(directory)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)


def synchronize(socket_path, destination, once=False):
    previous = None
    primary_file = Path("/var/lib/ryoku/greeter-primary")
    while True:
        try:
            with socket.socket(socket.AF_UNIX) as connection:
                connection.settimeout(10 if once else None)
                connection.connect(str(socket_path))
                connection.sendall(b"subscribe wallpaper\n")
                with connection.makefile("rb") as frames:
                    while True:
                        line = frames.readline(MAX_FRAME + 1)
                        if not line:
                            raise ConnectionError("Ryogami disconnected")
                        if len(line) > MAX_FRAME:
                            raise ValueError("Ryogami wallpaper frame is too large")
                        try:
                            frame = json.loads(line)
                            primary = primary_file.read_text().strip() if primary_file.is_file() else ""
                            entry = wallpaper_entry(frame, primary)
                            path = entry.get("path", "")
                            if not path:
                                if once:
                                    raise ValueError("No wallpaper in Ryogami snapshot")
                                continue
                            stat = Path(path).stat()
                            current = (path, stat.st_mtime_ns, stat.st_size)
                            if current != previous or not destination.is_file():
                                publish(path, destination)
                                previous = current
                                print("Nothing Interface: greeter background saved", flush=True)
                            if once:
                                return
                        except (OSError, ValueError, TypeError, AttributeError, Image.DecompressionBombError) as error:
                            if once:
                                raise
                            print(f"Nothing Interface: keeping last valid background ({error})", flush=True)
        except (OSError, ValueError, ConnectionError) as error:
            if once:
                raise
            print(f"Nothing Interface: waiting for Ryogami ({error})", flush=True)
            time.sleep(2)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--once", action="store_true", help="Save the current image and exit")
    parser.add_argument("--destination", type=Path, default=BACKGROUND)
    parser.add_argument("--socket", type=Path, default=Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")) / "ryogami.sock")
    args = parser.parse_args()
    synchronize(args.socket, args.destination, args.once)


if __name__ == "__main__":
    main()
