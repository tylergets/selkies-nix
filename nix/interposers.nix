{
  lib,
  stdenv,
  pkg-config,
  pipewire,
  src,
}:
stdenv.mkDerivation {
  pname = "selkies-interposers";
  version = "2.0.0rc0";
  inherit src;
  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ pipewire ];
  buildPhase = ''
    runHook preBuild
    make -C addons/js-interposer CC="$CC"
    make -C addons/v4l2-interposer CC="$CC"
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    install -Dm755 addons/js-interposer/selkies_joystick_interposer.so \
      "$out/lib/selkies_joystick_interposer.so"
    install -Dm755 addons/v4l2-interposer/selkies_v4l2_interposer.so \
      "$out/lib/selkies_v4l2_interposer.so"
    # The webcam interposer loads PipeWire using dlopen.
    patchelf --add-rpath ${lib.makeLibraryPath [ pipewire ]} \
      "$out/lib/selkies_v4l2_interposer.so"
    runHook postInstall
  '';
  dontShrinkRpath = true;
  meta = {
    description = "Selkies gamepad and webcam preload libraries";
    homepage = "https://github.com/selkies-project/selkies";
    license = lib.licenses.mpl20;
    platforms = lib.platforms.linux;
  };
}
