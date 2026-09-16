# Selkies for Nix

Self-contained Nix packaging for [Selkies](https://selkies.io/), the Linux
desktop streaming server. Builds the Python application, Rust audio/video
extensions, browser client, and native gamepad/webcam interposers from source.

## Build

With Nix flakes enabled:

```sh
nix build .#
./result/bin/selkies --version
./result/bin/selkies --help
```

You can also run it directly:

```sh
nix run .# -- --help
```

The pinned versions are Selkies **2.0.0rc0** and pixelflux/pcmflux **2.1.0rc0**.
These are upstream release candidates. The initial build compiles the Rust
extensions and can take several minutes.

Outputs:

| Attribute | Contents |
| --- | --- |
| `default`, `selkies` | Server, bundled web client, `selkies-resize`, `selkies-gpu-probe`, and interposer libraries |
| `pixelflux` | Python extension for screen capture and video encoding |
| `pcmflux` | Python extension for PulseAudio capture and Opus encoding |
| `selkies-web` | Built browser client and controller database |
| `interposers` | Native gamepad and webcam preload libraries |
| `stream` | Small launcher for streaming the current X11 desktop on localhost |

Linux x86_64 and ARM64 outputs are provided. The build and startup smoke test
have been verified on **x86_64-linux**; ARM64 has been evaluation-checked only.

## Quick test: stream the current X11 desktop

From a terminal inside your X11 desktop session:

```sh
nix build .#stream
./result/bin/stream
```

Or run it directly with `nix run .#stream`. Open **http://localhost:8080**.
Stop the stream with Ctrl+C.

The launcher inherits `DISPLAY`, `XAUTHORITY`, and your audio-session environment.
It uses X11 capture, binds to `127.0.0.1:8080`, disables login and HTTPS for this
local test, and disables automatic desktop resizing. It exits with an explanation
if `DISPLAY` is unset. Use it from an X.Org session; a Wayland session's Xwayland
display is not the full Wayland desktop.

Additional Selkies arguments override its defaults, for example:

```sh
nix run .#stream -- --port=8081 --use-cpu=true --audio-enabled=false
```

For a password-protected session, use the example below or pass
`--enable-basic-auth=true` with your credentials in the corresponding environment
variables.

## Run against an existing X11 desktop

Run as the user owning the graphical session, with its `DISPLAY`, `XAUTHORITY`
(if used), and `XDG_RUNTIME_DIR` environment. Audio uses the user's running
PulseAudio or PipeWire-Pulse server.

```bash
export SELKIES_BASIC_AUTH_USER="$USER"
read -rs -p 'Selkies password: ' SELKIES_BASIC_AUTH_PASSWORD; echo
export SELKIES_BASIC_AUTH_PASSWORD

nix run .# -- \
  --addr=127.0.0.1 \
  --port=8080 \
  --enable-https=false \
  --enable-resize=false
```

Open **http://localhost:8080**. This example disables resizing for an existing
physical display. Use `--use-cpu=true` to force software video encoding or
`--audio-enabled=false` when no audio server is available.

For remote access, use an SSH tunnel or configure HTTPS/a TLS reverse proxy.
For a separate headless Wayland session, upstream provides `--wayland=true`;
applications must connect to that compositor's socket. See the
[native installation guide](https://docs.selkies.io/native) and
[settings reference](https://docs.selkies.io/settings) for session setup.

This package starts the streaming server; a desktop session and audio server
are supplied separately. GPU encoding also requires the host's configured
graphics drivers and access to the relevant devices. The pixelflux package
includes the NixOS graphics-driver runtime search path. Hardware encoding and
interactive browser streaming have not been tested here.

### Optional gamepad and webcam interposers

The native libraries are installed at:

```text
result/lib/selkies_joystick_interposer.so
result/lib/selkies_v4l2_interposer.so
```

When using upstream's preload-based device forwarding, set `SELKIES_INTERPOSER`
and `SELKIES_WEBCAM_INTERPOSER` to the absolute library paths for the session.
Preload them into the applications receiving those devices, following the
upstream native-install instructions. Do not preload them into the Selkies
server itself. These builds match the selected architecture; 32-bit compatibility
libraries and the optional fake-udev shim are not included.

## Reproducibility and maintenance

All external source inputs are declared in `flake.nix` with **`flake = false`**,
including nixpkgs. `flake.lock` pins their revisions and content hashes. All
package definitions live under `nix/`; no external packaging flake or Nix
package recipe is imported.

Rust dependencies use upstream's `Cargo.lock` files and fixed-output vendor
hashes. Upstream does not commit npm lockfiles, so this repository includes
generated lockfiles under `nix/web-core/` and `nix/dashboard/`, alongside copies
of the corresponding upstream manifests. The web build reads the controller
database from its pinned input instead of downloading it during compilation.
Normal builds do not resolve fresh dependency versions.

To update nixpkgs or the controller database:

```sh
nix flake update nixpkgs controller-db
nix build .#
nix flake check
```

For Selkies upgrades, change the source tags in `flake.nix` and versions in the
package definitions together, then update their lock entries. If upstream's
Cargo dependencies change, recompute the affected vendor hashes. For web
dependency updates, sync the two local `package.json` files with upstream,
regenerate their lockfiles using `npm install --package-lock-only --ignore-scripts`,
and update the corresponding `npmDepsHash` values in `nix/web.nix`.

The `aitop` telemetry dependency is built from its pinned source distribution.
Its psutil version bound is relaxed to use nixpkgs' psutil; its GPU factory
import is checked during the build. Selkies' own dependency bounds are retained.

## Checks

```sh
nix flake check
nix flake check --all-systems --no-build
```

Package builds check Python imports, including the native extensions. The
flake's smoke check starts a virtual X11 display and the `stream` launcher,
then verifies HTTP delivery of the dashboard, JavaScript bundles, and
manifest. It does not require a GPU or a running desktop/audio session.

## Related work

Existing efforts researched while preparing these definitions:

- [Hyffer/selkies-nix](https://github.com/Hyffer/selkies-nix)
- [aldoborrero/flycast-romm](https://github.com/aldoborrero/flycast-romm/tree/main/nix/packages/selkies)

Build behavior follows the source repositories and Selkies' upstream
`scripts/ci/build-web.sh`.
