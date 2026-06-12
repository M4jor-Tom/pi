{
  description = "pi - Coding agent CLI";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { self
    , nixpkgs
    , flake-utils
    }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        packages = {
          default = pkgs.buildNpmPackage {
            pname = "pi-coding-agent";
            version = "0.79.1";
            src = pkgs.lib.cleanSource ./.;

            nodejs = pkgs.nodejs_22;

            npmDepsHash = "sha256-+8c/26yOn2w0unrEHhBhHXT0WtaJGamKtWzxa3BGeJE=";

            buildPhase = ''
              # Fix TS generic indexed access for tsgo 7.0 strictness
              sed -i 's/TProvider extends KnownProvider/TProvider extends KnownProvider \& keyof typeof MODELS/g' \
                packages/ai/src/models.ts

              # AI's generate-models needs network (Nix sandbox), so override
              # its build script to skip generation and use checked-in files.
              node -e 'const p=JSON.parse(require("fs").readFileSync("packages/ai/package.json","utf8")); p.scripts.build="tsgo -p tsconfig.build.json"; require("fs").writeFileSync("packages/ai/package.json",JSON.stringify(p,null,"	"))'

              npm run build
            '';

            installPhase = ''
              mkdir -p $out/bin $out/share/pi
              cp -r --preserve=mode . $out/share/pi
              rm -rf $out/share/pi/node_modules/.cache 2>/dev/null || true

              makeWrapper ${pkgs.nodejs_22}/bin/node $out/bin/pi \
                --add-flags "$out/share/pi/packages/coding-agent/dist/cli.js"
            '';

            nativeBuildInputs = [ pkgs.makeWrapper pkgs.pkg-config ];
            buildInputs = [
              pkgs.cairo
              pkgs.pixman
              pkgs.pango
              pkgs.libpng
              pkgs.libjpeg_turbo
              pkgs.giflib
              pkgs.freetype
              pkgs.fontconfig
            ];

            meta = {
              description = "Coding agent CLI with read, bash, edit, write tools and session management";
              homepage = "https://pi.dev";
              license = pkgs.lib.licenses.mit;
              mainProgram = "pi";
              platforms = pkgs.lib.platforms.linux;
            };
          };
        };

        apps.default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/pi";
        };

        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.nodejs_22
            pkgs.nodePackages.npm
            pkgs.biome
          ];
        };
      });
}
