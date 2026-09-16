{ writeShellApplication, selkies }:
writeShellApplication {
  name = "stream";
  runtimeInputs = [ selkies ];
  text = builtins.readFile ./stream.sh;
  meta.description = "Stream the current X11 desktop through Selkies on localhost";
}
