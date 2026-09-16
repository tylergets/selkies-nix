"""Build a pinned nixpkgs app and supervise its private X11 streaming session."""

import argparse
import json
import os
from pathlib import Path
import re
import secrets
import select
import signal
import subprocess
import sys
import tempfile
import time


def parse_args():
    parser = argparse.ArgumentParser(
        prog="stream-app",
        description="Stream an app in a new Xvfb desktop at http://localhost:8080.",
        epilog="Examples: stream-app xterm; stream-app --port 8081 firefox --no-remote",
    )
    parser.add_argument("--port", type=int, default=8080, help="localhost HTTP port (default: 8080)")
    parser.add_argument("--size", default="1280x720", help="virtual desktop size (default: 1280x720)")
    parser.add_argument("--exe", help="binary name for packages without a suitable meta.mainProgram")
    parser.add_argument("--exec", dest="executable", help="run an already-built executable instead of a nixpkgs attribute")
    parser.add_argument("app", nargs=argparse.REMAINDER, help="nixpkgs attribute followed by application arguments")
    args = parser.parse_args()
    if not 1 <= args.port <= 65535:
        parser.error("--port must be between 1 and 65535")
    if not re.fullmatch(r"[1-9][0-9]{0,4}x[1-9][0-9]{0,4}", args.size):
        parser.error("--size must be WIDTHxHEIGHT, for example 1920x1080")
    if args.executable and args.exe:
        parser.error("--exec and --exe cannot be combined")
    if args.app[:1] == ["--"]:
        args.app.pop(0)
    if not args.executable and not args.app:
        parser.error("specify a nixpkgs app, for example: stream-app xterm")
    return args


def resolve_app(args):
    if args.executable:
        return [str(Path(args.executable).resolve()), *args.app]
    attribute, *app_args = args.app
    attribute = attribute.removeprefix("nixpkgs#")
    if not re.fullmatch(r"[A-Za-z0-9_-]+(?:\.[A-Za-z0-9_-]+)*", attribute):
        raise ValueError("expected a nixpkgs attribute, for example xterm or kdePackages.konsole")
    if args.exe and not re.fullmatch(r"[A-Za-z0-9_.+-]+", args.exe):
        raise ValueError("--exe must be a binary name, not a path")
    components = " ".join(json.dumps(part) for part in attribute.split("."))
    expression = f'''let
      pkgs = import {os.environ["STREAM_APP_NIXPKGS"]} {{
        system = {json.dumps(os.environ["STREAM_APP_SYSTEM"])};
        config = {{}}; overlays = [];
      }};
      app = pkgs.lib.getAttrFromPath [ {components} ] pkgs;
    in '''
    nix = ["nix", "--extra-experimental-features", "nix-command"]
    print(f"Building {attribute} from pinned nixpkgs…", flush=True)
    subprocess.run(nix + ["build", "--no-link", "--expr", expression + "pkgs.lib.getBin app"], check=True)
    executable_expr = (
        f"pkgs.lib.getExe' app {json.dumps(args.exe)}" if args.exe else "pkgs.lib.getExe app"
    )
    executable = subprocess.check_output(
        nix + ["eval", "--raw", "--expr", expression + executable_expr], text=True
    )
    if app_args[:1] == ["--"]:
        app_args.pop(0)
    return [executable, *app_args]


def read_ready(stream, process, label):
    if not select.select([stream], [], [], 15)[0]:
        raise RuntimeError(f"{label} did not become ready within 15 seconds")
    line = stream.readline().strip()
    if not line or process.poll() is not None:
        raise RuntimeError(f"{label} exited before becoming ready")
    return line


def run_session(args, command):
    if not os.access(command[0], os.X_OK):
        raise ValueError(f"not an executable: {command[0]} (try --exe BINARY)")
    children = []

    def start(command, env, **kwargs):
        # Each service owns a process group so its descendants are cleaned up too.
        process = subprocess.Popen(command, env=env, start_new_session=True, **kwargs)
        children.append(process)
        return process

    with tempfile.TemporaryDirectory(prefix="selkies-app-") as directory:
        env = os.environ.copy()
        for name in ("DISPLAY", "WAYLAND_DISPLAY", "DBUS_SESSION_BUS_ADDRESS", "SESSION_MANAGER"):
            env.pop(name, None)
        env.update({
            "XDG_RUNTIME_DIR": directory,
            "XAUTHORITY": str(Path(directory) / "Xauthority"),
            "GDK_BACKEND": "x11", "QT_QPA_PLATFORM": "xcb",
            "SDL_VIDEODRIVER": "x11", "MOZ_ENABLE_WAYLAND": "0",
        })
        cookie = secrets.token_hex(16)
        Path(env["XAUTHORITY"]).touch(mode=0o600)
        subprocess.run(["xauth", "add", ":0", ".", cookie], env=env, check=True)
        try:
            # -displayfd allocates an unused display, without racing other sessions.
            xvfb = start([
                "Xvfb", "-displayfd", "1", "-screen", "0", f"{args.size}x24",
                "-nolisten", "tcp", "-auth", env["XAUTHORITY"],
                "-noreset", "-s", "0", "-dpms",
            ], env, stdout=subprocess.PIPE, text=True)
            number = read_ready(xvfb.stdout, xvfb, "Xvfb")
            env["DISPLAY"] = f":{number}"
            subprocess.run(["xauth", "add", env["DISPLAY"], ".", cookie], env=env, check=True)
            bus = start(["dbus-daemon", "--session", "--nofork", "--print-address=1"],
                        env, stdout=subprocess.PIPE, text=True)
            env["DBUS_SESSION_BUS_ADDRESS"] = read_ready(bus.stdout, bus, "D-Bus")
            wm = start(["openbox", "--config-file", os.environ["STREAM_APP_OPENBOX_CONFIG"]], env)
            server = start([
                "selkies", "--addr=127.0.0.1", f"--port={args.port}",
                "--wayland=false", "--enable-https=false", "--enable-basic-auth=false",
                "--enable-resize=false", "--use-cpu=true", "--audio-enabled=false",
                "--microphone-enabled=false", "--webcam-enabled=false", "--gamepad-enabled=false",
            ], env)
            app = start(command, env)
            print(f"Streaming {command[0]} on DISPLAY={env['DISPLAY']}\n"
                  f"Open http://localhost:{args.port} — close the app or press Ctrl+C to stop.", flush=True)
            while True:
                if app.poll() is not None:
                    return app.returncode
                for label, process in (("Xvfb", xvfb), ("D-Bus", bus), ("Openbox", wm), ("Selkies", server)):
                    if process.poll() is not None:
                        raise RuntimeError(f"{label} exited unexpectedly ({process.returncode})")
                time.sleep(0.1)
        finally:
            # Terminate groups even if their original parent already exited.
            for process in reversed(children):
                try:
                    os.killpg(process.pid, signal.SIGTERM)
                except ProcessLookupError:
                    pass
            deadline = time.monotonic() + 5
            for process in reversed(children):
                try:
                    process.wait(timeout=max(0, deadline - time.monotonic()))
                except subprocess.TimeoutExpired:
                    pass
            for process in reversed(children):
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                process.wait()


def interrupt(signum, frame):
    # Ignore subsequent interrupts while finally blocks stop the child processes.
    signal.signal(signal.SIGINT, signal.SIG_IGN)
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
    raise KeyboardInterrupt


if __name__ == "__main__":
    signal.signal(signal.SIGINT, interrupt)
    signal.signal(signal.SIGTERM, interrupt)
    try:
        options = parse_args()
        sys.exit(run_session(options, resolve_app(options)))
    except KeyboardInterrupt:
        sys.exit(130)
    except (ValueError, RuntimeError, OSError, subprocess.CalledProcessError) as error:
        print(f"stream-app: {error}", file=sys.stderr)
        sys.exit(1)
