{
  lib,
  buildPythonApplication,
  setuptools,
  wheel,
  src,
  web,
  pixelflux,
  pcmflux,
  interposers,
  aitop,
  prometheus-client,
  msgpack,
  psutil,
  watchdog,
  pillow,
  pulsectl-asyncio,
  dnspython,
  ifaddr,
  cffi,
  cryptography,
  google-crc32c,
  pyee,
  pylibsrtp,
  pyopenssl,
  aiohttp,
  aiofiles,
  uvloop,
  nvidia-ml-py,
  libxkbcommon,
  libglvnd,
  libx11,
  vulkan-loader,
  xrandr,
  xset,
  xclip,
  xdotool,
  libxcvt,
  xkeyboard-config,
  libpulseaudio,
}:
buildPythonApplication rec {
  pname = "selkies";
  version = "2.0.0rc0";
  inherit src;
  pyproject = true;
  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail 'version = "0.0.0.dev0"' 'version = "${version}"'
  '';
  preBuild = ''
    cp -r ${web} src/selkies/selkies_web
  '';
  postInstall = ''
    mkdir -p "$out/lib"
    ln -s ${interposers}/lib/*.so "$out/lib/"
  '';
  build-system = [
    setuptools
    wheel
  ];
  dependencies = [
    pixelflux
    pcmflux
    aitop
    prometheus-client
    msgpack
    psutil
    watchdog
    pillow
    pulsectl-asyncio
    dnspython
    ifaddr
    cffi
    cryptography
    google-crc32c
    pyee
    pylibsrtp
    pyopenssl
    aiohttp
    aiofiles
    uvloop
    nvidia-ml-py
  ];
  makeWrapperArgs = [
    "--prefix"
    "PATH"
    ":"
    "${
      lib.makeBinPath [
        xrandr
        xset
        xclip
        xdotool
        libxcvt
        libpulseaudio
      ]
    }"
    "--prefix"
    "LD_LIBRARY_PATH"
    ":"
    "${
      lib.makeLibraryPath [
        libxkbcommon
        libglvnd
        libx11
        vulkan-loader
      ]
    }"
    "--set-default"
    "XKB_CONFIG_ROOT"
    "${xkeyboard-config}/share/X11/xkb"
  ];
  pythonImportsCheck = [
    "selkies"
    "selkies.selkies_web"
    "pixelflux"
    "pcmflux"
  ];
  meta = {
    description = "Low-latency Linux desktop streaming to a web browser";
    homepage = "https://selkies.io";
    license = lib.licenses.mpl20;
    mainProgram = "selkies";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
