#!/usr/bin/env -S just --justfile

set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

export JUST_UNSTABLE := "1"
export MINIJINJA_CONFIG_FILE := justfile_dir() + "/.minijinja.toml"
export SOPS_AGE_KEY_FILE := justfile_dir() + "/age.agekey"

mod luffy "kubernetes/luffy"
mod robin "kubernetes/robin"

[private]
default:
    just -l

[private]
log lvl msg *args:
    gum log -t rfc3339 -s -l "{{ lvl }}" "{{ msg }}" {{ args }}

[private]
template file *args:
    minijinja-cli "{{ file }}" {{ args }} | op inject
