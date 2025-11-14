{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
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
          gum
          sops
          just
          krew
          yq-go
          fluxcd
          go-task
          kubectl
          kubectx
          python3
          helmfile
          talosctl
          minijinja
        ];
        shellHook = ''
          # Set environment variables based on the current directory as config root
          export JUST_UNSTABLE="1"
          export KUBERNETES_DIR="$(pwd)/kubernetes"
          export MINIJINJA_CONFIG_FILE="$(pwd)/.minijinja.toml"
          export SOPS_AGE_KEY_FILE="$(pwd)/age.agekey"
          export TALOSCONFIG="$(pwd)/talosconfig"
          export KUBECONFIG="$(pwd)/kubeconfig"
          export PATH="$HOME/.krew/bin:$PATH"
          krew install browse-pvc ctx ns oidc-login rook-ceph tmux-exec
        '';
      };
    });
  };
}
