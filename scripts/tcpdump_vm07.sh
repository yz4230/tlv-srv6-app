#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SSH_CONFIG="${ROOT_DIR}/infra/ssh_config"

ssh -F "$SSH_CONFIG" vm07 \
    "sudo tcpdump -ni '${DEV:-enp2s0}' -c '${COUNT:-1}' 'ip6 and dst ${VM07_SID:-fd00:a:7::1}'"
