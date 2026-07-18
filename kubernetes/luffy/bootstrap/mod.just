set positional-arguments
set quiet
set shell := ['bash', '-euo', 'pipefail', '-c']

kubernetes_dir := justfile_dir() + '/kubernetes/luffy'
bootstrap_dir := kubernetes_dir + '/bootstrap'
controller := `talosctl --context luffy config info --output json | jq --raw-output '.endpoints[]' | shuf -n 1`
nodes := `talosctl --context luffy config info -o yaml | yq -er '.nodes | join (" ")'`
lvm_device := "/dev/sda"
lvm_vg := "miroir-vg"

[private]
default: talos wait-talos k8s wait sops lvm crds apps

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

[doc('Wait for Talos API across all nodes')]
wait-talos:
    just log info "Running stage..." "stage" "$0"
    for n in {{ nodes }}; do \
        until talosctl --context luffy -n "$n" version --short &>/dev/null; do \
            just log info "Node $n not reachable or rebooting, waiting..." "stage" "$0" "node" "$n"; \
            sleep 5; \
        done; \
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

[doc('Bootstrap lvm volume group across nodes using J2 template')]
lvm:
    just log info "Running stage..." "stage" "$0"
    for n in {{ nodes }}; do \
        if kubectl --context admin@luffy get job/lvm-bootstrap-"$n" -n kube-system &>/dev/null; then \
            just log info "Job lvm-bootstrap-$n already exists, skipping apply" "stage" "$0" "node" "$n"; \
            continue; \
        fi; \
        minijinja-cli {{ bootstrap_dir }}/helmfile.d/templates/lvm-bootstrap.yaml.j2 \
          -D node_name="$n" \
          -D device_path={{ lvm_device }} \
          -D vg_name={{ lvm_vg }} | kubectl --context admin@luffy apply -f -; \
    done
    just log info "Waiting for LVM volume group creation..." "stage" "$0"
    for n in {{ nodes }}; do \
        kubectl --context admin@luffy wait --for=condition=complete job/lvm-bootstrap-"$n" -n kube-system --timeout=120s; \
    done

[doc('Apply Helmfile CRDs and Apps')]
helmfile: lvm crds apps

[doc('Apply Helmfile CRDs')]
crds:
    just log info "Running stage..." "stage" "$0"
    if ! helmfile --kube-context admin@luffy -f "{{ bootstrap_dir }}/helmfile.d/00-crds.yaml" template -q | yq ea -e 'select(.kind == "CustomResourceDefinition")' | kubectl apply --context admin@luffy --server-side --field-manager bootstrap --force-conflicts -f -; then \
      just log fatal "Failed to apply crds" "stage" "$0"; \
    fi;

[doc('Apply Helmfile Apps')]
apps:
    just log info "Running stage..." "stage" "$0"
    if ! helmfile --kube-context admin@luffy  -f "{{ bootstrap_dir }}/helmfile.d/01-apps.yaml" sync --hide-notes; then \
      just log fatal "Failed to sync helmfile" "stage" "$0"; \
    fi
