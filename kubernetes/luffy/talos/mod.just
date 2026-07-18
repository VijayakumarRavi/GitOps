set quiet
set shell := ['bash', '-euo', 'pipefail', '-c']

kubernetes_dir := justfile_dir() + '/kubernetes/luffy'
talos_dir := kubernetes_dir + '/talos'
controller := `talosctl --context luffy config info -o yaml | yq -e '.endpoints[0]'`
nodes := `talosctl --context luffy config info -o yaml | yq -e '.nodes | join (" ")'`

[private]
default:
    just -l luffy talos

[doc('Apply Talos config to a node')]
apply-node node *args:
    just log info "Applying Talos machineconfig" "node" "{{ node }}"
    just luffy talos render-config "{{ node }}" | talosctl --context luffy -n "{{ node }}" apply-config -f /dev/stdin {{ args }}

[doc('Apply Talos config to all nodes in the cluster')]
apply-cluster *args:
    for node in {{ nodes }}; do \
        just luffy talos apply-node "${node}" {{ args }}; \
    done

[doc('Download Talos machine image')]
download-image version schematic:
    gum spin --title "Downloading Talos {{ version }} ..." -- \
    curl -sfL --remove-on-error --retry 5 --retry-delay 5 --retry-all-errors \
        -o "{{ talos_dir }}/talos-{{ version }}-{{ replace_regex(schematic, '^(.{8}).*', '$1') }}.iso" \
        "https://factory.talos.dev/image/{{ schematic }}/{{ version }}/metal-amd64-secureboot.iso"
    just log info "Downloaded Talos" version "{{ version }}" schematic "{{ schematic }}"

[doc('Generate schematic ID from Talos schematic')]
schematic-id:
    curl -sX POST --data-binary @<(just template "{{ talos_dir }}/schematic.yaml.j2") "https://factory.talos.dev/schematics" | jq -r '.id'

[doc('Reboot a node')]
reboot-node node:
    gum confirm "Reboot node {{ node }}?" --default="No" && \
        talosctl --context luffy -n {{ node }} reboot -m powercycle || exit 0

[doc('Render Talos config for a node')]
render-config node:
    export IS_CONTROLLER="$(just luffy talos machine-controller {{ node }})"; \
    export SCHEMATIC="$(just luffy talos schematic-id)"; \
    export TALOS_VERSION="$(just luffy talos talos-version)"; \
    export K8S_VERSION="$(just luffy talos k8s-version)"; \
    talosctl machineconfig patch <(just template "{{ talos_dir }}/machineconfig.yaml.j2") \
        -p @<(just template "{{ talos_dir }}/nodes/{{ node }}.yaml.j2")
    if [ -f "{{ talos_dir }}/extensions.yaml.j2" ]; then just template "{{ talos_dir }}/extensions.yaml.j2"; fi

[doc('Reset a node')]
reset-node node mode="reboot":
    gum confirm "Reset node {{ node }}?" --default="No" && \
        talosctl --context luffy -n "{{ node }}" reset --system-labels-to-wipe STATE --system-labels-to-wipe EPHEMERAL --system-labels-to-wipe u-local-hostpath --graceful=false {{ if mode == "reboot" { "--reboot" } else { "" } }} || exit 0

[doc('Reset all nodes in the cluster')]
reset-cluster mode="reboot":
    for node in {{ nodes }}; do \
        just luffy talos reset-node "${node}" "{{ mode }}"; \
    done

[doc('Shutdown a node')]
shutdown-node node:
    gum confirm "Shutdown node {{ node }}?" --default="No" && \
        talosctl --context luffy -n "{{ node }}" shutdown --force || exit 0

[doc('Upgrade Kubernetes version on the cluster')]
upgrade-k8s version:
    talosctl --context luffy -n "{{ controller }}" upgrade-k8s --to {{ version }}

[doc('Upgrade Talos version on all nodes across the cluster')]
upgrade-cluster:
    for node in {{ nodes }}; do \
        just luffy talos upgrade-node "${node}"; \
    done

[doc('Upgrade Talos version on a node')]
upgrade-node node:
    talosctl --context luffy -n "{{ node }}" upgrade -i "$(just luffy talos machine-image {{ node }})" -m powercycle --timeout=10m

[private]
machine-controller node:
    just template "{{ talos_dir }}/nodes/{{ node }}.yaml.j2" | yq -e 'select(.machine) | (.machine.type == "controlplane") // ""'

[doc('Get the machine image for a given node')]
[private]
machine-image node:
    talosctl --context luffy --nodes {{ node }} get machineconfig -o yaml | yq -e 'select(.metadata.id == "v1alpha1") | .spec' | yq -e 'select(.machine) | .machine.install.image'

[doc('Fetch Talos version from configuration')]
[private]
talos-version:
    yq eval '.talos_version' "{{ talos_dir }}/version.yaml"

[doc('Fetch Kubernetes version from configuration')]
[private]
k8s-version:
    yq eval '.k8s_version' "{{ talos_dir }}/version.yaml"
