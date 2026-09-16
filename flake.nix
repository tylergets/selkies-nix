{
  description = "Selkies remote desktop streaming, built from source";

  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixos-unstable";
      flake = false;
    };
    selkies = {
      url = "github:selkies-project/selkies/2.0.0rc0";
      flake = false;
    };
    pixelflux = {
      url = "github:selkies-project/pixelflux/2.1.0rc0";
      flake = false;
    };
    pcmflux = {
      url = "github:selkies-project/pcmflux/2.1.0rc0";
      flake = false;
    };
    controller-db = {
      url = "github:mdqinc/SDL_GameControllerDB";
      flake = false;
    };
    aitop = {
      url = "https://files.pythonhosted.org/packages/45/cf/f0e41130609d4bdef94852e60e4cccee6304e38edb44d71571f230b4c4fb/aitop-0.16.10.tar.gz";
      flake = false;
    };
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = (import (nixpkgs + "/lib")).genAttrs systems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        import ./nix { inherit pkgs inputs; }
      );

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.selkies}/bin/selkies";
          meta.description = "Selkies remote desktop streaming server";
        };
        stream = {
          type = "app";
          program = "${self.packages.${system}.stream}/bin/stream";
          meta.description = "Stream the current X11 desktop on localhost";
        };
        stream-app = {
          type = "app";
          program = "${self.packages.${system}.stream-app}/bin/stream-app";
          meta.description = "Stream a nixpkgs application in a private Xvfb desktop";
        };
      });

      formatter = forAllSystems (system: (import nixpkgs { inherit system; }).nixfmt);

      checks = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          smoke =
            pkgs.runCommand "selkies-smoke"
              {
                nativeBuildInputs = [
                  pkgs.python3
                  pkgs.xorg-server
                ];
              }
              ''
                python ${./tests/smoke.py} ${self.packages.${system}.stream}/bin/stream
                touch "$out"
              '';
          stream-app =
            pkgs.runCommand "selkies-stream-app-test"
              {
                nativeBuildInputs = [ pkgs.python3 ];
              }
              ''
                python ${./tests/stream_app.py} \
                  ${self.packages.${system}.stream-app}/bin/stream-app \
                  ${pkgs.xterm}/bin/xterm
                touch "$out"
              '';
        }
      );
    };
}
