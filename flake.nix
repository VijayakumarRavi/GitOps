{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    talhelper.url = "github:budimanjojo/talhelper";
    talhelper.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = inputs: let
    # Supported systems for NixOS and MacOS
    supportedSystems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin"];
    forAllSystems = inputs.nixpkgs.lib.genAttrs supportedSystems;
  in {
    # Development shell with pre-commit hooks
    devShells = forAllSystems (system: {
      default = inputs.nixpkgs.legacyPackages.${system}.mkShell {
        buildInputs = with inputs.nixpkgs.legacyPackages.${system}; [
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
        ];
        shellHook = ''
          # Set environment variables based on the current directory as config root
          export KUBERNETES_DIR="$(pwd)/kubernetes/luffy"
          export SOPS_AGE_KEY_FILE="$(pwd)/age.agekey"
          export TALOSCONFIG="$(pwd)/kubernetes/luffy/talos/clusterconfig/talosconfig"
          # Tells pip to put packages into $PIP_PREFIX instead of the usual locations.
          # See https://pip.pypa.io/en/stable/user_guide/#environment-variables.
          export PIP_PREFIX=$(pwd)/_build/pip_packages
          export PYTHONPATH="$PIP_PREFIX/${inputs.nixpkgs.legacyPackages.${system}.python313.sitePackages}:$PYTHONPATH"
          export PATH="$PIP_PREFIX/bin:$PATH"
          unset SOURCE_DATE_EPOCH
        '';
      };
    });
  };
}
