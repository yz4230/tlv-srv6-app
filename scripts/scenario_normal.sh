#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SSH_CONFIG="${ROOT_DIR}/infra/ssh_config"
ENCAP_BIN="${ENCAP_BIN:-${ROOT_DIR}/ip-seg6-encap/build/ip-seg6-encap}"
REMOTE_DIR="${REMOTE_DIR:-/opt/tlv-srv6-app}"
REMOTE_ENCAP="${REMOTE_DIR}/ip-seg6-encap"
SEGS="fd00:a:7:0:8200::,fd00:a:3:0:8300::,fd00:a:6::1,fd00:a:4::d4"

if [[ ! -x "$ENCAP_BIN" ]]; then
    echo "missing ip-seg6-encap binary: $ENCAP_BIN" >&2
    echo "run: make -C ip-seg6-encap build" >&2
    exit 1
fi

ssh -F "$SSH_CONFIG" vm02 "sudo mkdir -p '$REMOTE_DIR' && sudo chown debian:debian '$REMOTE_DIR'"
scp -F "$SSH_CONFIG" "$ENCAP_BIN" "vm02:${REMOTE_ENCAP}"
ssh -F "$SSH_CONFIG" vm02 \
    "chmod +x '$REMOTE_ENCAP' && sudo '$REMOTE_ENCAP' add --prefix 10.4.0.0/24 --dev enp3s0 --reserve 8 --segs '$SEGS'"

if [[ -n "${PING_INTERVAL:-}" ]]; then
    ssh -F "$SSH_CONFIG" vm01 "sudo ping -c '${COUNT:-1}' -i '$PING_INTERVAL' 10.4.0.5"
else
    ssh -F "$SSH_CONFIG" vm01 "ping -c '${COUNT:-1}' 10.4.0.5"
fi
