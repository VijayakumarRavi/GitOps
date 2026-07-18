set quiet
set shell := ['bash', '-euo', 'pipefail', '-c']

mod bootstrap "bootstrap"
mod talos "talos"

kubernetes_dir := justfile_dir() + '/kubernetes/luffy'

[private]
default:
    just -l luffy

#[doc('Apply local Flux Kustomization')]
#apply-ks ns ks:
#    just k8s render-local-ks "{{ ns }}" "{{ ks }}" | kubectl --context admin@luffy apply --server-side --field-manager=kustomize-controller -f /dev/stdin

[doc('Browse a PVC')]
browse-pvc namespace claim:
    kubectl --context admin@luffy browse-pvc -n {{ namespace }} -i mirror.gcr.io/alpine:latest {{ claim }}

#[doc('Delete local Flux Kustomization')]
#delete-ks ns ks:
#    just k8s render-local-ks "{{ ns }}" "{{ ks }}" | kubectl --context admin@luffy delete -f /dev/stdin

[doc('Open a shell on a node')]
node-shell node:
    kubectl --context admin@luffy debug node/{{ node }} -n default -it --image="mirror.gcr.io/alpine:latest" --profile sysadmin
    kubectl --context admin@luffy delete pod -n default -l app.kubernetes.io/managed-by=kubectl-debug

[doc('Prune pods in Failed, Pending, or Succeeded state')]
prune-pods:
    for phase in Failed Pending Succeeded UnexpectedAdmissionError Unknown; do \
        kubectl --context admin@luffy delete pods -A --field-selector status.phase="$phase" --ignore-not-found=true; \
    done

[doc('Snapshot VolSync PVCs')]
snapshot:
    kubectl --context admin@luffy get replicationsources --no-headers -A | while read -r ns name _; do \
        kubectl --context admin@luffy -n "$ns" patch replicationsources "$name" --type merge -p '{"spec":{"trigger":{"manual":"$(date +%s)"}}}'; \
    done

[doc('Suspend or resume VolSync')]
volsync state:
    flux --context admin@luffy {{ state }} kustomization volsync
    flux --context admin@luffy -n system {{ state }} helmrelease volsync
    kubectl --context admin@luffy -n system scale deployment volsync --replicas {{ if state != "suspend" { "1" } else { "0" } }}

[doc('Sync single ExternalSecret')]
sync-es ns name:
    kubectl --context admin@luffy -n "{{ ns }}" annotate --field-manager flux-client-side-apply --overwrite es "{{ name }}" force-sync="$(date +%s)"

[doc('Sync single GitRepository')]
sync-git ns name:
    kubectl --context admin@luffy -n "{{ ns }}" annotate --field-manager flux-client-side-apply --overwrite gitrepo "{{ name }}" reconcile.fluxcd.io/requestedAt="$(date +%s)"

[doc('Sync single HelmRelease')]
sync-hr ns name:
    kubectl --context admin@luffy -n "{{ ns }}" annotate --field-manager flux-client-side-apply --overwrite hr "{{ name }}" reconcile.fluxcd.io/requestedAt="$(date +%s)" reconcile.fluxcd.io/forceAt="$(date +%s)"

[doc('Sync single Kustomization')]
sync-ks ns name:
    kubectl --context admin@luffy -n "{{ ns }}" annotate --field-manager flux-client-side-apply --overwrite ks "{{ name }}" reconcile.fluxcd.io/requestedAt="$(date +%s)"

[doc('Sync single OCIRepository')]
sync-oci ns name:
    kubectl --context admin@luffy -n "{{ ns }}" annotate --field-manager flux-client-side-apply --overwrite ocirepo "{{ name }}" reconcile.fluxcd.io/requestedAt="$(date +%s)"

[doc('Sync all ExternalSecrets')]
sync-all-es:
    kubectl --context admin@luffy get es --no-headers -A | while read -r ns name _; do \
        just luffy sync-es "$ns" "$name"; \
    done

[doc('Sync all GitRepositories')]
sync-all-git:
    kubectl --context admin@luffy get gitrepo --no-headers -A | while read -r ns name _; do \
        just luffy sync-git "$ns" "$name"; \
    done

[doc('Sync all HelmReleases')]
sync-all-hr:
    kubectl --context admin@luffy get hr --no-headers -A | while read -r ns name _; do \
        just luffy sync-hr "$ns" "$name"; \
    done

[doc('Sync all Kustomizations')]
sync-all-ks:
    kubectl --context admin@luffy get ks --no-headers -A | while read -r ns name _; do \
        just luffy sync-ks "$ns" "$name"; \
    done

[doc('Sync all OCIRepositories')]
sync-all-oci:
    kubectl --context admin@luffy get ocirepo --no-headers -A | while read -r ns name _; do \
        just luffy sync-oci "$ns" "$name"; \
    done

[doc('Trigger Kopiur Snapshotpolicy')]
snapshot-kopiur ns name:
    kubectl --context admin@luffy kopiur -n "{{ ns }}" snapshot now --policy "{{ name }}"

[doc('Trigger all Kopiur Snapshotpolicies')]
snapshot-kopiur-all:
    kubectl --context admin@luffy get snapshotpolicies.kopiur.home-operations.com --no-headers -A | while read -r ns name _; do \
        just luffy snapshot-kopiur "$ns" "$name"; \
    done

[doc('View a secret')]
view-secret namespace secret:
    kubectl --context admin@luffy view-secret -n {{ namespace }} {{ secret }}

#[private]
#render-local-ks ns ks:
#    flux-local build ks --namespace "{{ ns }}" --path "{{ kubernetes_dir }}/flux/cluster" "{{ ks }}"

[doc('Suspend apps and trigger manual backups for VolSync and Postgres')]
stop-and-backup:
    #!/usr/bin/env bash
    set -euo pipefail
    TIMESTAMP="$(date +%F-%H%M%S)"
    IGNORE_NS=" flux-system kube-system database volsync-system network storage "

    VOLSYNC_NAMESPACES=$(kubectl --context admin@luffy get replicationsources -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\n"}{end}' | sort -u || true)
    for ns in $VOLSYNC_NAMESPACES; do
        if [ "$ns" = "" ]; then continue; fi

        if [[ "$IGNORE_NS" != *" $ns "* ]]; then
            just log info "Suspending workloads and scaling down apps" "namespace" "$ns"
            flux --context admin@luffy suspend hr --all -n "$ns" >/dev/null 2>&1 || true
            kubectl --context admin@luffy scale deploy,sts --all --replicas=0 -n "$ns" >/dev/null 2>&1 || true
        fi

        just log info "Triggering VolSync backups" "namespace" "$ns"
        for rs in $(kubectl --context admin@luffy get replicationsources -n "$ns" -o name); do
            kubectl --context admin@luffy patch "$rs" -n "$ns" --type merge -p "{\"spec\":{\"trigger\":{\"manual\":\"${TIMESTAMP}\"}}}" >/dev/null 2>&1
        done
    done

    PG_NAMESPACES=$(kubectl --context admin@luffy get postgresclusters -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\n"}{end}' | sort -u || true)
    for ns in $PG_NAMESPACES; do
        if [ "$ns" = "" ]; then continue; fi
        just log info "Triggering Postgres backups" "namespace" "$ns"
        for pg in $(kubectl --context admin@luffy get postgresclusters -n "$ns" -o name); do
            kubectl --context admin@luffy annotate -n "$ns" "$pg" postgres-operator.crunchydata.com/pgbackrest-backup="${TIMESTAMP}" --overwrite >/dev/null 2>&1
        done
    done

    just log info "Waiting 15 seconds for backups to provision..."
    sleep 15

    for ns in $VOLSYNC_NAMESPACES; do
        if [ "$ns" = "" ] || [[ "$IGNORE_NS" == *" $ns "* ]]; then continue; fi
        until ! kubectl --context admin@luffy get replicationsources -n "$ns" -o jsonpath='{.items[*].status.conditions[?(@.type=="Synchronizing")].status}' | grep -q "True"; do
            just log info "Waiting for VolSync backups to complete. Retrying in 10 seconds..." "namespace" "$ns"
            sleep 10
        done
    done

    for ns in $PG_NAMESPACES; do
        if [ "$ns" = "" ]; then continue; fi
        until ! kubectl --context admin@luffy get jobs -l postgres-operator.crunchydata.com/pgbackrest-backup=manual -n "$ns" -o jsonpath='{.items[*].status.active}' | grep -q "1"; do
            just log info "Waiting for Postgres backups to complete. Retrying in 10 seconds..." "namespace" "$ns"
            sleep 10
        done
    done

    just log info "All manual backups completed successfully"
