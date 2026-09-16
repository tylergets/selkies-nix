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
  cmake,
  nasm,
  autoPatchelfHook,
  autoAddDriverRunpath,
  x264,
  ffmpeg,
  pixman,
  libx11,
  libxext,
  libxfixes,
  libva,
  libdrm,
  libinput,
  libxkbcommon,
  libgbm,
  wayland,
  libglvnd,
  pipewire,
  src,
}:
buildPythonPackage rec {
  pname = "pixelflux";
  version = "2.1.0rc0";
  inherit src;
  pyproject = true;
  cargoRoot = "pixelflux";
  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit
      pname
      version
      src
      cargoRoot
      ;
    hash = "sha256-JS5xZb3QKLitVj1IB53WTR+JA00xp+SYGITqlszUwc8=";
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
    rustPlatform.bindgenHook
    pkg-config
    cmake
    nasm
    autoPatchelfHook
    autoAddDriverRunpath
  ];
  dontUseCmakeConfigure = true;
  buildInputs = [
    x264
    ffmpeg
    pixman
    libx11
    libxext
    libxfixes
    libva
    libdrm
    libinput
    libxkbcommon
    libgbm
    wayland
  ];
  # These libraries are opened dynamically rather than linked by the compiler.
  appendRunpaths = [
    (lib.makeLibraryPath [
      wayland
      libglvnd
      pipewire
    ])
  ];
  pythonImportsCheck = [ "pixelflux" ];
  meta = {
    description = "Selkies X11/Wayland capture and video encoding extension";
    homepage = "https://github.com/selkies-project/pixelflux";
    license = with lib.licenses; [
      mpl20
      gpl2Plus
    ];
    platforms = lib.platforms.linux;
  };
}
