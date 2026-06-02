set quiet
set shell := ['bash', '-euo', 'pipefail', '-c']

kubernetes_dir := justfile_dir() + '/kubernetes/robin'
talos_dir := kubernetes_dir + '/talos'
controller := `talosctl --context robin config info -o yaml | yq -e '.endpoints[0]'`

[private]
default:
    just -l robin talos

[doc('Apply Talos config to a node')]
apply-node node *args:
    just robin talos render-config "{{ node }}" | talosctl --context robin -n "{{ node }}" apply-config -f /dev/stdin {{ args }}

[doc('Download Talos machine image')]
download-image version schematic:
    gum spin --title "Downloading Talos {{ version }} ..." -- \
    curl -sfL --remove-on-error --retry 5 --retry-delay 5 --retry-all-errors \
        -o "{{ talos_dir }}/talos-{{ version }}-{{ replace_regex(schematic, '^(.{8}).*', '$1') }}.iso" \
        "https://factory.talos.dev/image/{{ schematic }}/{{ version }}/metal-amd64.iso"
    just log info "Downloaded Talos" version "{{ version }}" schematic "{{ schematic }}"

[doc('Generate schematic ID from Talos schematic')]
gen-schematic-id:
    curl -sX POST --data-binary @<(just template "{{ talos_dir }}/schematic.yaml.j2") "https://factory.talos.dev/schematics" | jq -r '.id'

[doc('Reboot a node')]
reboot-node node:
    gum confirm "Reboot node {{ node }}?" --default="No" && \
        talosctl --context robin -n {{ node }} reboot -m powercycle || exit 0

[doc('Render Talos config for a node')]
render-config node:
    export IS_CONTROLLER="$(just robin talos machine-controller {{ node }})"; \
    talosctl machineconfig patch <(just template "{{ talos_dir }}/machineconfig.yaml.j2") \
        -p @<(just template "{{ talos_dir }}/nodes/{{ node }}.yaml.j2")
    if [ -f "{{ talos_dir }}/extensions.yaml.j2" ]; then just template "{{ talos_dir }}/extensions.yaml.j2"; fi

[doc('Reset a node')]
reset-node node:
    gum confirm "Reset node {{ node }}?" --default="No" && \
        talosctl --context robin -n "{{ node }}" reset --graceful=false --system-labels-to-wipe STATE --system-labels-to-wipe EPHEMERAL || exit 0

[doc('Shutdown a node')]
shutdown-node node:
    gum confirm "Shutdown node {{ node }}?" --default="No" && \
        talosctl --context robin -n "{{ node }}" shutdown --force || exit 0

[doc('Upgrade Kubernetes version on the cluster')]
upgrade-k8s version:
    talosctl --context robin -n "{{ controller }}" upgrade-k8s --to {{ version }}

[doc('Upgrade Talos version on a node')]
upgrade-node node:
    talosctl --context robin -n "{{ node }}" upgrade -i "$(just robin talos machine-image)" -m powercycle --timeout=10m

[private]
machine-controller node:
    just template "{{ talos_dir }}/nodes/{{ node }}.yaml.j2" | yq -e 'select(.machine) | (.machine.type == "controlplane") // ""'

[private]
machine-image:
    just template "{{ talos_dir }}/machineconfig.yaml.j2" | yq -e 'select(.machine) | .machine.install.image'
