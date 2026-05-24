set positional-arguments := true
set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

kubernetes_dir := justfile_dir() + '/kubernetes/robin'
bootstrap_dir := kubernetes_dir + '/bootstrap'
controller := `talosctl --context robin config info --output json | jq --raw-output '.endpoints[]' | shuf -n 1`
nodes := `talosctl --context robin config info -o yaml | yq -er '.nodes | join (" ")'`
lvm_device := "/dev/disk/by-partlabel/r-openebs-lvm"
lvm_vg := "openebs-vg"

[private]
default: talos k8s wait sops lvm crds apps

[doc('Install Talos')]
talos:
    just log info "Running stage..." "stage" "$0"
    for n in {{ nodes }}; do \
        if ! op=$(just robin talos apply-node "$n" --insecure 2>&1); then \
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
    until op=$(talosctl --context robin -n "{{ controller }}" bootstrap 2>&1 || true) && [[ "$op" == *"AlreadyExists"* ]]; do \
        just log info "Kubernetes bootstrap in progress. Retrying in 5 seconds..." "stage" "$0"; \
        sleep 5; \
    done

[doc('Fetch kubeconfig')]
kubeconfig lb="cilium":
    just log info "Running stage..." "stage" "$0"
    if ! talosctl --context robin kubeconfig -n "{{ controller }}" -f --force-context-name admin@robin {{ justfile_dir() }}; then \
        just log fatal "Failed to fetch kubeconfig" "stage" "$0"; \
    fi
    if [[ "{{ lb }}" != "cilium" ]]; then \
        if ! kubectl config set-cluster admin@robin --server "https://{{ controller }}:6443"; then \
            just log fatal "Failed to set kubectl cluster server address" "stage" "$0"; \
        fi; \
    fi

[doc('Wait for nodes to be not-ready')]
wait:
    just log info "Running stage..." "stage" "$0"
    if ! kubectl --context admin@robin wait nodes --for=condition=Ready=True --all --timeout=10s &>/dev/null; then \
        until kubectl --context admin@robin wait nodes --for=condition=Ready=False --all --timeout=10s &>/dev/null; do \
            just log info "Nodes not available, waiting for nodes to be available. Retrying in 5 seconds..." "stage" "$0"; \
            sleep 5; \
        done \
    fi

[doc('Apply sops secrets')]
sops:
    just log info "Running stage..." "stage" "$0"
    if !  op=$(kubectl create --context admin@robin ns flux-system 2>&1); then \
      if [[ "$op" == *"AlreadyExists"* ]]; then \
        just log info "Namespace flux-system already exists, skipping creation" "stage" "$0"; \
      else \
        just log fatal "Failed to create namespace flux-system" "stage" "$0" "output" "$op"; \
      fi; \
    fi
    if ! op=$(kubectl --context admin@robin create secret generic sops-age --namespace=flux-system --from-literal=age.agekey="$(op read op://automation/flux/sops_private_key)" 2>&1); then \
      if [[ "$op" == *"already exists"* ]]; then \
        just log info "Secret sops-age already exists, skipping creation" "stage" "$0"; \
      else \
        just log fatal "Failed to create secret sops-age" "stage" "$0" "output" "$op"; \
      fi; \
    fi

[doc('Bootstrap lvm volume group using J2 template')]
lvm:
    just log info "Running stage..." "stage" "$0"
    minijinja-cli {{ bootstrap_dir }}/helmfile.d/templates/lvm-bootstrap.yaml.j2 \
      -D device_path={{ lvm_device }} \
      -D vg_name={{ lvm_vg }}  | kubectl --context admin@robin apply -f -
    just log info "Waiting for LVM volume group creation..." "stage" "$0"
    kubectl --context admin@robin wait --for=condition=complete job/lvm-bootstrap -n kube-system --timeout=120s

[doc('Apply Helmfile CRDs and Apps')]
helmfile: crds apps

[doc('Apply Helmfile CRDs')]
crds:
    just log info "Running stage..." "stage" "$0"
    if ! helmfile --kube-context admin@robin -f "{{ bootstrap_dir }}/helmfile.d/00-crds.yaml" template -q | kubectl apply --context admin@robin --server-side -f -; then \
      just log fatal "Failed to apply crds" "stage" "$0"; \
    fi;

[doc('Apply Helmfile Apps')]
apps:
    just log info "Running stage..." "stage" "$0"
    if ! helmfile --kube-context admin@robin -f "{{ bootstrap_dir }}/helmfile.d/01-apps.yaml" sync --hide-notes; then \
      just log fatal "Failed to sync helmfile" "stage" "$0"; \
    fi
