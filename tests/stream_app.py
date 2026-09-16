"""Exercise a real X11 app, HTTP serving, isolation, and both shutdown paths."""

import json
import os
from pathlib import Path
import signal
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request


def descendants(pid):
    try:
        children = [int(child) for child in Path(f"/proc/{pid}/task/{pid}/children").read_text().split()]
    except FileNotFoundError:
        return []
    return children + [nested for child in children for nested in descendants(child)]


def alive(pid):
    try:
        return Path(f"/proc/{pid}/stat").read_text().split(") ", 1)[1][0] != "Z"
    except FileNotFoundError:
        return False


probe = '''import json, os, pathlib, time
root = pathlib.Path(os.environ["APP_TEST_ROOT"])
(root / "ready.json").write_text(json.dumps(dict(os.environ)))
while not (root / "exit").exists():
    time.sleep(0.1)
'''

for shutdown in ("signal", "app-exit"):
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        env = os.environ | {
            "HOME": directory, "APP_TEST_ROOT": directory,
            "DISPLAY": ":987", "WAYLAND_DISPLAY": "not-the-host-session",
            "DBUS_SESSION_BUS_ADDRESS": "not-the-host-bus",
            "SELKIES_FILE_MANAGER_PATH": directory,
        }
        with socket.socket() as listener:
            listener.bind(("127.0.0.1", 0))
            port = listener.getsockname()[1]
        # Outside the sandbox this also exercises building xterm from pinned nixpkgs.
        app = ["--exec", sys.argv[2]] if len(sys.argv) > 2 else ["xterm"]
        command = [sys.argv[1], "--port", str(port), "--size", "1024x768", *app,
                   "--", "-T", "Selkies test application", "-e", sys.executable, "-c", probe]
        with (root / "session.log").open("w+") as log:
            session = subprocess.Popen(command, env=env, stdout=log, stderr=log)
            try:
                deadline = time.monotonic() + 180
                while not (root / "ready.json").exists():
                    assert session.poll() is None, "stream-app exited before the X11 application started"
                    assert time.monotonic() < deadline, "Application startup timed out"
                    time.sleep(0.1)
                app_env = json.loads((root / "ready.json").read_text())
                assert app_env["DISPLAY"] != env["DISPLAY"]
                assert "WAYLAND_DISPLAY" not in app_env
                assert app_env["DBUS_SESSION_BUS_ADDRESS"].startswith("unix:")
                assert app_env["GDK_BACKEND"] == "x11"
                runtime = Path(app_env["XDG_RUNTIME_DIR"])
                auth = Path(app_env["XAUTHORITY"])
                assert runtime.is_dir() and auth.is_file()
                display_socket = Path(f"/tmp/.X11-unix/X{app_env['DISPLAY'][1:]}")
                assert display_socket.exists()
                for _ in range(150):
                    assert session.poll() is None, "Session exited before HTTP startup"
                    try:
                        with urllib.request.urlopen(f"http://127.0.0.1:{port}", timeout=1) as response:
                            assert b"<script" in response.read()
                        break
                    except (urllib.error.URLError, TimeoutError):
                        time.sleep(0.1)
                else:
                    raise AssertionError("Selkies HTTP startup timed out")
                pids = descendants(session.pid)
                assert len(pids) >= 5, "Expected Xvfb, D-Bus, Openbox, Selkies and the application"
                if shutdown == "signal":
                    session.send_signal(signal.SIGTERM)
                else:
                    (root / "exit").touch()
                assert session.wait(timeout=20) == (130 if shutdown == "signal" else 0)
                assert not runtime.exists(), "Session runtime directory was not removed"
                assert not display_socket.exists(), "Xvfb socket was not removed"
                assert not any(alive(pid) for pid in pids), "Session left child processes running"
                print(f"stream-app: isolated X11 application, HTTP, and {shutdown} cleanup OK")
            except BaseException:
                log.flush()
                log.seek(0)
                print(log.read(), file=sys.stderr)
                raise
            finally:
                if session.poll() is None:
                    session.terminate()
                    session.wait(timeout=20)
