#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SSH_CONFIG="${ROOT_DIR}/infra/ssh_config"

ssh -F "$SSH_CONFIG" vm06 \
    "sudo tcpdump -ni '${DEV:-enp2s0}' -c '${COUNT:-1}' 'ip6 and dst ${VM06_SID:-fd00:a:6::1}'"

