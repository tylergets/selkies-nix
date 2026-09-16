# Run inside the X11 session so DISPLAY and XAUTHORITY identify its desktop.
: "${DISPLAY:?DISPLAY is unset. Run stream from a terminal in your X11 desktop.}"

# A local test session, with no login and no changes to the display resolution.
# Explicit arguments come last so callers can override these defaults.
exec selkies \
  --addr=127.0.0.1 \
  --port=8080 \
  --wayland=false \
  --enable-https=false \
  --enable-basic-auth=false \
  --enable-resize=false \
  "$@"
