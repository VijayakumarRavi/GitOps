#! /bin/bash

kubectl create ns flux-system

op read op://automation/flux/sops_private_key |
  kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=/dev/stdin

helmfile sync --file ./helmfile.yaml
