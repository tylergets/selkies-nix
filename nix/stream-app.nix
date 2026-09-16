{ writeShellApplication, python3, nix, xorg-server, xauth, openbox, dbus, selkies,
  nixpkgsSource, stdenv }:
writeShellApplication {
  name = "stream-app";
  runtimeInputs = [ python3 nix xorg-server xauth openbox dbus selkies ];
  runtimeEnv = {
    STREAM_APP_NIXPKGS = toString nixpkgsSource;
    STREAM_APP_SYSTEM = stdenv.hostPlatform.system;
    STREAM_APP_OPENBOX_CONFIG = toString ./openbox.xml;
  };
  text = ''
    exec python3 ${./stream-app.py} "$@"
  '';
  meta.description = "Run a nixpkgs application in an Xvfb desktop streamed by Selkies";
}
