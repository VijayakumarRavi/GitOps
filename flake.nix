{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    talhelper.url = "github:budimanjojo/talhelper";
    talhelper.inputs.nixpkgs.follows = "nixpkgs";

    # Git pre-commit hooks
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
    pre-commit-hooks.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = inputs: let
    # Supported systems for NixOS and MacOS
    supportedSystems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin"];
    forAllSystems = inputs.nixpkgs.lib.genAttrs supportedSystems;

    # Pre-commit hooks configuration for all systems
    pre-commit = forAllSystems (system: {
      pre-commit-check = inputs.pre-commit-hooks.lib.${system}.run {
        src = ./.;
        hooks = {
          alejandra.enable = true;
          actionlint.enable = true;
          shellcheck.enable = true;
          flake-checker.enable = true;
          check-symlinks.enable = true;
          end-of-file-fixer.enable = true;
          detect-private-keys.enable = true;
          trim-trailing-whitespace.enable = true;
          trim-trailing-whitespace.stages = ["pre-commit"];
        };
      };
    });
  in {
    # Development shell with pre-commit hooks
    devShells = forAllSystems (system: {
      default = inputs.nixpkgs.legacyPackages.${system}.mkShell {
        inherit (pre-commit.${system}.pre-commit-check) shellHook;
        buildInputs = with inputs.nixpkgs.legacyPackages.${system};
          [
            jq
            git
            flux
            sops
            go-task
            kubectl
            python3
            helmfile
            talosctl
            minijinja
            inputs.talhelper.packages.${system}.default
          ]
          ++ pre-commit.${system}.pre-commit-check.enabledPackages;
      };
    });
  };
}
