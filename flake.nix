{

  description = "funkwhale flake";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      version = "1.1.2";
      supportedSystems = [ "x86_64-linux" "i686-linux" "aarch64-linux" ];
      forAllSystems = f:
        nixpkgs.lib.genAttrs supportedSystems (system: f system);
    in {
      overlay = final: prev: {

        funkwhale-frontend = with final;
          stdenv.mkDerivation {
            pname = "funkwhale-frontend";
            inherit version;

            nativeBuildInputs = [ pkgs.unzip ];

            unpackCmd = "unzip $curSrc";

            src = fetchurl {
              url =
                "https://dev.funkwhale.audio/funkwhale/funkwhale/-/jobs/artifacts/${version}/download?job=build_front";
              sha256 = "1wyxgp8vr3id4cxvf445m64xj4nhv04ka8h406hhbfps6i420vvl";
            };

            installPhase = ''
              mkdir $out
              cp -R ./dist/* $out
            '';
          };

        funkwhale = with final;
          stdenv.mkDerivation {
            pname = "funkwhale";
            inherit version;

            src = fetchurl {
              url =
                "https://dev.funkwhale.audio/funkwhale/funkwhale/-/archive/${version}/funkwhale-${version}.tar.bz2";
              sha256 = "0d0flp5v0swmiliz1bj1rxhpxqsbqy23jra3dnha12v41sklha87";
            };

            installPhase = ''
              sed "s|env -S|env|g" -i front/scripts/*.sh
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
          };

      };

      defaultPackage = forAllSystems (system:
        (import nixpkgs {
          inherit system;
          overlays = [ self.overlay ];
        }).funkwhale);

      nixosModule = { ... }: {
        nixpkgs.overlays = [ self.overlay ];
        imports = [ ./module.nix ];
      };
    };
}
