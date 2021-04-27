{

  #funkwhale-front url: https://dev.funkwhale.audio/funkwhale/funkwhale/-/jobs/artifacts/1.1.1/download?job=build_front
  description = "funkwhale flake";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "i686-linux" "aarch64-linux" ];
      forAllSystems = f:
        nixpkgs.lib.genAttrs supportedSystems (system: f system);
    in {
      overlay = final: prev: {

        funkwhale = with final;
          (stdenv.mkDerivation {
            pname = "funkwhale";
            version = "1.1.1";

            src = fetchurl {
              url =
                "https://dev.funkwhale.audio/funkwhale/funkwhale/-/archive/${version}/funkwhale-${version}.tar.bz2";
              sha256 = lib.fakeSha256;
            };

            installPhase = ''
              mkdir $out
              cp -R ./* $out
            '';

            meta = with lib; {
              description = "A social platform to enjoy and share music";
              homepage = "https://funkwhale.audio";
              license = licenses.agpl3;
              platforms = platforms.linux;
              maintainers = with maintainers; [ critbase ];
            };
          });

      };

      defaultPackage = forAllSystems (system:
        (import nixpkgs {
          inherit system;
          overlays = [ self.overlay ];
        }).funkwhale);

      nixosModule = (import ./module.nix);
    };
}
