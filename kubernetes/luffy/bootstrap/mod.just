set positional-arguments
set quiet
set shell := ['bash', '-euo', 'pipefail', '-c']

kubernetes_dir := justfile_dir() + '/kubernetes/luffy'
bootstrap_dir := kubernetes_dir + '/bootstrap'
controller := `talosctl --context luffy config info --output json | jq --raw-output '.endpoints[]' | shuf -n 1`
nodes := `talosctl --context luffy config info -o yaml | yq -er '.nodes | join (" ")'`

[private]
default: talos k8s wait sops crds apps

[doc('Install Talos')]
talos:
    just log info "Running stage..." "stage" "$0"
    for n in {{ nodes }}; do \
        if ! op=$(just luffy talos apply-node "$n" --insecure 2>&1); then \
            if [[ "$op" == *"certificate required"* ]]; then \
                just log info "Talos already configured, skipping apply of config" "stage" "$0" "node" "$n"; \
                continue; \
            fi; \
            just log fatal "Failed to apply Talos configuration" "stage" "$0" "node" "$n" "output" "$op"; \
        fi; \
    done

[doc('Install Kubernetes')]
k8s:
    just log info "Running stage..." "stage" "$0"
    until op=$(talosctl --context luffy -n "{{ controller }}" bootstrap 2>&1 || true) && [[ "$op" == *"AlreadyExists"* ]]; do \
        just log info "Kubernetes bootstrap in progress. Retrying in 5 seconds..." "stage" "$0"; \
        sleep 5; \
    done

[doc('Wait for nodes to be not-ready')]
wait:
    just log info "Running stage..." "stage" "$0"
    if ! kubectl --context admin@luffy wait nodes --for=condition=Ready=True --all --timeout=10s &>/dev/null; then \
        until kubectl --context admin@luffy wait nodes --for=condition=Ready=False --all --timeout=10s &>/dev/null; do \
            just log info "Nodes not available, waiting for nodes to be available. Retrying in 5 seconds..." "stage" "$0"; \
            sleep 5; \
        done \
    fi

[doc('Apply sops secrets')]
sops:
    just log info "Running stage..." "stage" "$0"
    if !  op=$(kubectl create ns flux-system --context admin@luffy 2>&1); then \
      if [[ "$op" == *"AlreadyExists"* ]]; then \
        just log info "Namespace flux-system already exists, skipping creation" "stage" "$0"; \
      else \
        just log fatal "Failed to create namespace flux-system" "stage" "$0" "output" "$op"; \
      fi; \
    fi
    if ! op=$(kubectl create secret generic sops-age --context admin@luffy --namespace=flux-system --from-literal=age.agekey="$(op read op://automation/flux/sops_private_key)" 2>&1); then \
      if [[ "$op" == *"already exists"* ]]; then \
        just log info "Secret sops-age already exists, skipping creation" "stage" "$0"; \
      else \
        just log fatal "Failed to create secret sops-age" "stage" "$0" "output" "$op"; \
      fi; \
    fi

[doc('Apply Helmfile CRDs and Apps')]
helmfile: crds apps

[doc('Apply Helmfile CRDs')]
crds:
    just log info "Running stage..." "stage" "$0"
    if ! helmfile --kube-context admin@luffy -f "{{ bootstrap_dir }}/helmfile.d/00-crds.yaml" template -q | kubectl apply --context admin@luffy --server-side -f -; then \
      just log fatal "Failed to apply crds" "stage" "$0"; \
    fi;

[doc('Apply Helmfile Apps')]
apps:
    just log info "Running stage..." "stage" "$0"
    if ! helmfile --kube-context admin@luffy  -f "{{ bootstrap_dir }}/helmfile.d/01-apps.yaml" sync --hide-notes; then \
      just log fatal "Failed to sync helmfile" "stage" "$0"; \
    fi
