#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SSH_CONFIG="${ROOT_DIR}/infra/ssh_config"

ssh -F "$SSH_CONFIG" vm02 "printf 'tlv-secret\n' | sudo ip sr hmac set 1 sha256 >/dev/null 2>/dev/null"

ssh -F "$SSH_CONFIG" vm02 \
    "sudo ip route replace 10.4.0.0/24 encap seg6 mode encap segs fd00:a:3:0:8100::,fd00:a:3:0:8200:1::,fd00:a:3:0:8300::,fd00:a:6::1,fd00:a:4::d4 hmac 1 dev enp3s0"

if [[ -n "${PING_INTERVAL:-}" ]]; then
    ssh -F "$SSH_CONFIG" vm01 "sudo ping -c '${COUNT:-1}' -i '$PING_INTERVAL' 10.4.0.5"
else
    ssh -F "$SSH_CONFIG" vm01 "ping -c '${COUNT:-1}' 10.4.0.5"
fi
