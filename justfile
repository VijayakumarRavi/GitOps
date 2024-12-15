default:
    just --list --unsorted

# convert Secret to SealedSecret
secret file='':
    #!/usr/bin/env sh
    kubeseal -f {{ file }} -o yaml > tmp.yaml && \
    mv tmp.yaml {{ file }}
