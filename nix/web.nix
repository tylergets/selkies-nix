{
  buildNpmPackage,
  src,
  controllerDb,
}:
let
  version = "2.0.0rc0";
  core = buildNpmPackage {
    pname = "selkies-web-core";
    inherit version src;
    sourceRoot = "source/addons/selkies-web-core";
    postPatch = ''
      cp ${./web-core/package-lock.json} package-lock.json
      substituteInPlace gendb.js \
        --replace-fail 'const response = await fetch(DB_URL);' \
          'const response = { ok: true, text: async () => fs.readFileSync("${controllerDb}/gamecontrollerdb.txt", "utf8") };'
    '';
    npmDepsHash = "sha256-dS/CX46Q2SwqUlMTrTwND8Q/VchBmak9G4jzmnpN1F4=";
    installPhase = ''
      runHook preInstall
      cp -r dist "$out"
      runHook postInstall
    '';
  };
in
buildNpmPackage {
  pname = "selkies-web";
  inherit version src;
  sourceRoot = "source/addons/selkies-dashboard";
  postPatch = ''
    cp ${./dashboard/package-lock.json} package-lock.json
  '';
  npmDepsHash = "sha256-jdXhb9dr7nn3PuMB43yWb+8AKlzm7pelGmRn7i/8bs4=";
  env.SELKIES_INJECT = "1";
  preBuild = ''
    chmod u+w ../selkies-web-core
    cp -r ${core} ../selkies-web-core/dist
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p dist/src
    cp ${core}/selkies-core.js dist/src/
    cp ../universal-touch-gamepad/universalTouchGamepad.js dist/src/
    cp ../../docs/assets/logo/icon-512x512.png dist/icon-512.png
    cp ../../docs/assets/logo/favicon.ico dist/favicon.ico
    touch dist/__init__.py
    printf '%s' '{"name":"Selkies","short_name":"Selkies","display":"fullscreen","background_color":"#000000","theme_color":"#000000","icons":[{"src":"icon-512.png","type":"image/png","sizes":"512x512"}],"start_url":"."}' > dist/manifest.json
    cp -r dist "$out"
    runHook postInstall
  '';
}
