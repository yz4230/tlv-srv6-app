#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFRA_DIR="${ROOT_DIR}/infra"
BPF_OBJ="${BPF_OBJ:-${ROOT_DIR}/build/srv6_tlv.bpf.o}"
REMOTE_DIR="${REMOTE_DIR:-/opt/tlv-srv6-app}"
REMOTE_OBJ="${REMOTE_DIR}/srv6_tlv.bpf.o"
SID_DEV="${SID_DEV:-enp2s0}"

if [[ ! -f "$BPF_OBJ" ]]; then
    echo "missing BPF object: $BPF_OBJ" >&2
    echo "run: make build" >&2
    exit 1
fi

if [[ ! -f "${INFRA_DIR}/ssh_config" ]]; then
    echo "missing VM ssh config: ${INFRA_DIR}/ssh_config" >&2
    echo "run: scripts/up.sh" >&2
    exit 1
fi

ssh -F "${INFRA_DIR}/ssh_config" vm03 "sudo mkdir -p '$REMOTE_DIR' && sudo chown debian:debian '$REMOTE_DIR'"
scp -F "${INFRA_DIR}/ssh_config" "$BPF_OBJ" "vm03:${REMOTE_OBJ}"

ssh -F "${INFRA_DIR}/ssh_config" vm03 \
    "sudo ip -6 route replace 'fd00:a:3:0:8100::/80' encap bpf xmit obj '$REMOTE_OBJ' section lwt_xmit/tlv_gateway dev '$SID_DEV' && \
     sudo ip -6 route replace 'fd00:a:3:0:8200::/80' encap bpf xmit obj '$REMOTE_OBJ' section lwt_xmit/tlv_embedder dev '$SID_DEV' && \
     sudo ip -6 route replace 'fd00:a:3:0:8300::/80' encap bpf xmit obj '$REMOTE_OBJ' section lwt_xmit/tlv_selector dev '$SID_DEV' && \
     ip -6 route show 'fd00:a:3:0:8100::/80' && \
     ip -6 route show 'fd00:a:3:0:8200::/80' && \
     ip -6 route show 'fd00:a:3:0:8300::/80'"
