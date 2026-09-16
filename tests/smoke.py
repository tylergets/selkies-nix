"""Start the packaged server on a virtual X display and fetch its web client."""

import os
import pathlib
import re
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request


def stop(process):
    if process is not None:
        process.terminate()
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()


with tempfile.TemporaryDirectory() as directory:
    root = pathlib.Path(directory)
    env = os.environ | {
        "HOME": directory,
        "XDG_RUNTIME_DIR": directory,
        "DISPLAY": ":99",
        "SELKIES_FILE_MANAGER_PATH": directory,
    }
    xvfb = server = None
    with (root / "server.log").open("w+") as log:
        try:
            xvfb = subprocess.Popen(
                ["Xvfb", ":99", "-screen", "0", "1280x720x24", "-nolisten", "tcp", "-ac"],
                env=env, stdout=log, stderr=log,
            )
            for _ in range(100):
                if xvfb.poll() is not None:
                    raise RuntimeError("Xvfb exited before becoming ready")
                if pathlib.Path("/tmp/.X11-unix/X99").exists():
                    break
                time.sleep(0.1)
            else:
                raise TimeoutError("Xvfb did not become ready")

            with socket.socket() as listener:
                listener.bind(("127.0.0.1", 0))
                port = listener.getsockname()[1]
            server = subprocess.Popen(
                [
                    sys.argv[1], "--addr=127.0.0.1", f"--port={port}",
                    "--enable-https=false", "--enable-basic-auth=false",
                    "--audio-enabled=false", "--microphone-enabled=false",
                    "--webcam-enabled=false", "--gamepad-enabled=false",
                    "--enable-clipboard=false", "--enable-resize=false",
                    "--use-cpu=true",
                ],
                env=env, stdout=log, stderr=log,
            )
            url = f"http://127.0.0.1:{port}"
            for _ in range(150):
                if server.poll() is not None:
                    raise RuntimeError(f"Selkies exited with {server.returncode}")
                try:
                    with urllib.request.urlopen(url, timeout=1) as response:
                        html = response.read().decode()
                    break
                except (urllib.error.URLError, TimeoutError):
                    time.sleep(0.1)
            else:
                raise TimeoutError("Selkies did not serve its web client")

            scripts = re.findall(r'<script[^>]+src="([^"]+\.js)"', html)
            assert scripts, "No JavaScript bundle found in the web client"
            for asset in [*scripts, "/manifest.json", "/src/selkies-core.js"]:
                with urllib.request.urlopen(url + "/" + asset.lstrip("./"), timeout=5) as response:
                    assert response.status == 200
                    assert response.read(), f"Empty web asset: {asset}"
            print("Selkies startup and bundled web assets: OK")
        except BaseException:
            log.flush()
            log.seek(0)
            print(log.read(), file=sys.stderr)
            raise
        finally:
            stop(server)
            stop(xvfb)
