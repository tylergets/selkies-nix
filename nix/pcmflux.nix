{
  lib,
  buildPythonPackage,
  setuptools,
  setuptools-rust,
  wheel,
  rustPlatform,
  cargo,
  rustc,
  pkg-config,
  libpulseaudio,
  libopus,
  src,
}:
buildPythonPackage rec {
  pname = "pcmflux";
  version = "2.1.0rc0";
  inherit src;
  pyproject = true;
  cargoRoot = "pcmflux";
  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit
      pname
      version
      src
      cargoRoot
      ;
    hash = "sha256-/2wt5leA+tSVe+mx7CqSAQhsU+H9yEuyOEtmkzZAsbQ=";
  };
  postPatch = ''
    substituteInPlace setup.py --replace-fail 'version="2.1.0"' 'version="${version}"'
  '';
  build-system = [
    setuptools
    setuptools-rust
    wheel
  ];
  nativeBuildInputs = [
    cargo
    rustc
    rustPlatform.cargoSetupHook
    pkg-config
  ];
  buildInputs = [
    libpulseaudio
    libopus
  ];
  pythonImportsCheck = [ "pcmflux" ];
  meta = {
    description = "Selkies PulseAudio capture and Opus encoding extension";
    homepage = "https://github.com/selkies-project/pcmflux";
    license = lib.licenses.mpl20;
    platforms = lib.platforms.linux;
  };
}
