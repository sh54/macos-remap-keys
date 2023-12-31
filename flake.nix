{
  description = "Remap keys with pure macOS functionality";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  # Also add flake-compat to inputs and outputs to easily allow updating
  inputs.flake-compat = {
    url = "github:edolstra/flake-compat";
    flake = false;
  };

  outputs = { self, nixpkgs, flake-utils, flake-compat }:
    flake-utils.lib.eachSystem [
      "aarch64-darwin"
      "x86_64-darwin"
    ] (system:
      let
        name = "macos-remap-keys";
        pkgs = import nixpkgs { inherit system; };
        python = pkgs.python3;
        dependencies = pypkgs: with pypkgs; [
          pyyaml
        ];
        python-pkg = python.pkgs.buildPythonPackage {
          name = name;
          version = "0.1";
          src = ./.;
          propagatedBuildInputs = dependencies python.pkgs;
        };
      in
      rec {
        packages."${name}" = python-pkg;
        defaultPackage = self.packages.${system}.${name};

        # `nix run`
        apps.${name} = flake-utils.lib.mkApp {
          drv = packages.${name};
          exePath = "/bin/remap.py";
        };
        defaultApp = apps.${name};

        # `nix run .#launchd`
        apps.launchd = {
          type = "app";
          program =
            let drv = pkgs.writeShellScript "remap-launchd" ''
              ${defaultPackage}/bin/remap.py \
                --config ${./config.yaml} \
                --keytables ${./keytables.yaml} \
                --launchd-plist \
                ~/Library/LaunchAgents/ch.veehait.macos-remap-keys.plist
            '';
            in drv.outPath;
        };

        # `nix run .#hidutil`
        apps.hidutil = let
          script = pkgs.writeShellScriptBin "example-script" ''
            hidutil property --set \
              `${python-pkg}/bin/remap.py \
                --config ${./config.yaml} \
                --keytables ${./keytables.yaml} \
                --hidutil-property`
          '';
        in {
          type = "app";
          program = "${script}/bin/example-script";
        };

        # `nix develop`
        devShell = pkgs.mkShell {
          name = "${name}-shell";
          nativeBuildInputs = [
            pkgs.black
            (dependencies python.pkgs)
          ];
        };
      }
    );
}
