<div align="center">

 # GitOps Workflow for Kubernetes Cluster

_managed by [flux](https://github.com/fluxcd/flux2), [Renovate](https://github.com/renovatebot/renovate) and [GitHub Actions](https://github.com/features/actions)_ :robot:

Kubernetes cluster stats:

[![Talos](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.bjw-s.dev%2Ftalos_version&style=for-the-badge&logo=talos&logoColor=white&color=orange&label=talos)](https://talos.dev)&nbsp;
[![Kubernetes](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.bjw-s.dev%2Fkubernetes_version&style=for-the-badge&logo=kubernetes&logoColor=white&color=blue&label=k8s)](https://kubernetes.io)&nbsp;&nbsp;
[![Flux](https://img.shields.io/endpoint?url=https%3A%2F%2Fkromgo.bjw-s.dev%2Fflux_version&style=for-the-badge&logo=flux&logoColor=white&color=blue&label=flux)](https://fluxcd.io)

[![Age-Days](https://kromgo.hamlet-ide.ts.net/cluster_age_days?format=badge)](https://github.com/kashalls/kromgo/)&nbsp;
[![Node-Count](https://kromgo.hamlet-ide.ts.net/cluster_node_count?format=badge)](https://github.com/kashalls/kromgo/)&nbsp;
[![Alerts](https://kromgo.hamlet-ide.ts.net/cluster_alert_count?format=badge)](https://github.com/kashalls/kromgo/)&nbsp;
[![Pod-Count](https://kromgo.hamlet-ide.ts.net/cluster_pod_count?format=badge)](https://github.com/kashalls/kromgo/)&nbsp;
[![CPU-Usage](https://kromgo.hamlet-ide.ts.net/cluster_cpu_usage?format=badge)](https://github.com/kashalls/kromgo/)&nbsp;
[![Memory-Usage](https://kromgo.hamlet-ide.ts.net/cluster_memory_usage?format=badge)](https://github.com/kashalls/kromgo/)

</div>
<br>

## :computer:&nbsp; Infrastructure

See the [talos cluster setup](../kubernetes/luffy/talos/) for more detail about hardware and infrastructure

## :gear:&nbsp; Setup

(run from the repo root)

Use talhelper to generate the config files in the `clusterconfig` directory.

```shell
task talos:generate-clusterconfig
```

Bootstrap the talos nodes. It may take some time for the cluster to be ready.

```shell
task k8s-bootstrap:talos
```

## kubernetes setup & bootstrapping

Bootstrap the kubernetes cluster with required prerequisites (cilium CNI, CRDs, flux, etc).

```shell
task k8s-bootstrap:apps
```

## :wrench:&nbsp; Workloads (by namespace in kubernetes/)

* [cert-manager](../kubernetes/luffy/apps/cert-manager/)
* [database](../kubernetes/luffy/apps/database/)
* [downloads](../kubernetes/luffy/apps/downloads/)
* [flux-system](../kubernetes/luffy/apps/flux-system/)
* [media](../kubernetes/luffy/apps/media/)
* [monitoring](../kubernetes/luffy/apps/monitoring/)
* [network](../kubernetes/luffy/apps/network/)
* [security](../kubernetes/luffy/apps/security/)
* [selfhosted](../kubernetes/luffy/apps/selfhosted/)
* [storage](../kubernetes/luffy/apps/storage/)
* [system](../kubernetes/luffy/apps/system/)
* [system-upgrade](../kubernetes/luffy/apps/system-upgrade/)
* [system-controllers](../kubernetes/luffy/apps/system-controllers/)
 
## :robot:&nbsp; Automation

* [Renovate](https://github.com/renovatebot/renovate) keeps workloads up-to-date by scanning the repo and opening pull requests when it detects a new container image update or a new helm chart
* [System Upgrade Controller](https://github.com/rancher/system-upgrade-controller) automatically upgrades talos and kubernetes to new versions as they are released


