#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SSH_CONFIG="${ROOT_DIR}/infra/ssh_config"

for vm in vm07 vm03; do
    ssh -F "$SSH_CONFIG" "$vm" "sudo bpftool prog tracelog" | sed -u "s/^/${vm}: /" &
done

wait
