{
  description = "Port of ttf-ms-win11{,-fod}-auto* packages to Nix";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    {
      self,
      nixpkgs,
    }:
    let
      systems = [
        "i686-linux"
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems f;
      pkgsFor = system: nixpkgs.legacyPackages.${system};
      packagesFor =
        system:
        let
          pkgs = pkgsFor system;
        in
        pkgs.lib.mapAttrs' (
          jsonFileName: _:
          let
            pkgName = pkgs.lib.removeSuffix ".json" jsonFileName;
            pkgData = builtins.fromJSON (builtins.readFile ./pkgs/${jsonFileName});
          in
          {
            name = pkgName;
            value = (import ./mkPackage.nix) {
              inherit pkgs pkgName;
              inherit (pkgData)
                archive
                files
                iso
                outputHash
                parentDir
                version
                ;
            };
          }
        ) (builtins.readDir ./pkgs);
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          allPackages = packagesFor system;
        in
        allPackages
        // rec {
          ttf-ms-win11-auto-all = pkgs.symlinkJoin {
            name = "ttf-ms-win11-auto-all";
            paths = pkgs.lib.attrValues allPackages;
          };
          default = ttf-ms-win11-auto-all;
        }
      );
      overlays.default = final: _prev: packagesFor final.stdenv.hostPlatform.system final;
      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          updateDeps = with pkgs; [
            bash
            git
            jq
            parallel
            (python3.withPackages (p: [ p.fontforge ]))
          ];
          update-pkgs = pkgs.writeShellApplication {
            name = "update-pkgs";
            runtimeInputs = updateDeps;
            text = ''
              bash ${self}/update-pkgs.sh update
            '';
          };
          update-pkgs-force = pkgs.writeShellApplication {
            name = "update-pkgs-force";
            runtimeInputs = updateDeps;
            text = ''
              bash ${self}/update-pkgs.sh force-update
            '';
          };
        in
        {
          default = pkgs.mkShell {
            packages = updateDeps ++ [
              update-pkgs
              update-pkgs-force
            ];
          };
        }
      );
    };
}
