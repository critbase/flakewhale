{

  description = "funkwhale flake";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "i686-linux" "aarch64-linux" ];
      forAllSystems = f:
        nixpkgs.lib.genAttrs supportedSystems (system: f system);
    in {
      overlay = final: prev: {

        funkwhale-frontend = with final;
          (let version = "1.1.1";
          in stdenv.mkDerivation {
            pname = "funkwhale-frontend";
            inherit version;

            nativeBuildInputs = [ pkgs.unzip ];

            unpackCmd = "unzip $curSrc";

            src = fetchurl {
              url =
                "https://dev.funkwhale.audio/funkwhale/funkwhale/-/jobs/artifacts/${version}/download?job=build_front";
              sha256 = "2U8N6qiLjZDdELNjz4F6gPnSgiQZ6LvHKCus0nNREns=";
            };

            installPhase = ''
              mkdir $out
              cp -R ./* $out
            '';
          });

        funkwhale = with final;
          (let version = "1.1.1";
          in stdenv.mkDerivation {
            pname = "funkwhale";
            inherit version;

            src = fetchurl {
              url =
                "https://dev.funkwhale.audio/funkwhale/funkwhale/-/archive/${version}/funkwhale-${version}.tar.bz2";
              sha256 = "0qn26acfww6bbvcmwhvsgmlbc6y9bp3hjvhhywfi6f116x2vs81d";
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
