{ pkgs, inputs }:
let
  python = pkgs.python3Packages;
  pixelflux = python.callPackage ./pixelflux.nix { src = inputs.pixelflux; };
  pcmflux = python.callPackage ./pcmflux.nix { src = inputs.pcmflux; };
  aitop = python.buildPythonPackage {
    pname = "aitop";
    version = "0.16.10";
    src = inputs.aitop;
    pyproject = true;
    build-system = [
      python.setuptools
      python.wheel
    ];
    dependencies = [ python.psutil ];
    pythonRelaxDeps = [ "psutil" ];
    pythonImportsCheck = [ "aitop.core.gpu.factory" ];
  };
  web = pkgs.callPackage ./web.nix {
    src = inputs.selkies;
    controllerDb = inputs.controller-db;
  };
  interposers = pkgs.callPackage ./interposers.nix { src = inputs.selkies; };
  selkies = python.callPackage ./selkies.nix {
    src = inputs.selkies;
    inherit
      pixelflux
      pcmflux
      aitop
      web
      interposers
      ;
  };
in
{
  inherit
    selkies
    pixelflux
    pcmflux
    interposers
    ;
  selkies-web = web;
  stream = pkgs.callPackage ./stream.nix { inherit selkies; };
  stream-app = pkgs.callPackage ./stream-app.nix {
    inherit selkies;
    nixpkgsSource = inputs.nixpkgs;
  };
  default = selkies;
}
