#!/usr/bin/env python3
"""Create the narrow, user-writable SDDM background cache (one-time root setup)."""

import os
from pathlib import Path
import pwd
import stat


def main():
    if os.geteuid() != 0:
        raise SystemExit("Run this helper with pkexec or sudo.")
    uid = int(os.environ.get("PKEXEC_UID") or os.environ.get("SUDO_UID") or "0")
    if uid < 1000:
        raise SystemExit("Cannot identify the desktop user. Invoke with pkexec or sudo from that user's session.")
    user = pwd.getpwuid(uid)
    for directory in (Path("/var/lib/ryoku"), Path("/var/lib/ryoku/nothing-interface")):
        if directory.is_symlink():
            raise SystemExit(f"Refusing a symbolic link: {directory}")
        directory.mkdir(mode=0o755, exist_ok=True)
        status = directory.stat()
        if not stat.S_ISDIR(status.st_mode) or status.st_uid != 0 or status.st_mode & 0o022:
            raise SystemExit(f"Expected a root-owned directory without group/world write access: {directory}")
    directory = Path("/var/lib/ryoku/nothing-interface/background")
    if directory.is_symlink():
        raise SystemExit(f"Refusing a symbolic link: {directory}")
    directory.mkdir(mode=0o755, exist_ok=True)
    if directory.stat().st_uid not in (0, uid):
        raise SystemExit("This greeter background is managed by a different desktop user.")
    os.chown(directory, uid, user.pw_gid)
    os.chmod(directory, 0o755)
    print(f"Background cache ready for {user.pw_name}: {directory}")


if __name__ == "__main__":
    main()
