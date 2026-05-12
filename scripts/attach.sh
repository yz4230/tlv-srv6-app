#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFRA_DIR="${ROOT_DIR}/infra"
BPF_OBJ="${BPF_OBJ:-${ROOT_DIR}/build/srv6_tlv.bpf.o}"
REMOTE_DIR="${REMOTE_DIR:-/opt/tlv-srv6-app}"
REMOTE_OBJ="${REMOTE_DIR}/srv6_tlv.bpf.o"
VM07_SID_DEV="${VM07_SID_DEV:-enp3s0}"
VM03_SID_DEV="${VM03_SID_DEV:-enp2s0}"

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

for vm in vm07 vm03; do
    ssh -F "${INFRA_DIR}/ssh_config" "$vm" "sudo mkdir -p '$REMOTE_DIR' && sudo chown debian:debian '$REMOTE_DIR'"
    scp -F "${INFRA_DIR}/ssh_config" "$BPF_OBJ" "${vm}:${REMOTE_OBJ}"
done

ssh -F "${INFRA_DIR}/ssh_config" vm07 \
    "sudo ip -6 route replace 'fd00:a:7:0:8200::/80' encap bpf xmit obj '$REMOTE_OBJ' section lwt_xmit/tlv_embedder dev '$VM07_SID_DEV' && \
     ip -6 route show 'fd00:a:7:0:8200::/80'"
ssh -F "${INFRA_DIR}/ssh_config" vm03 \
    "sudo ip -6 route replace 'fd00:a:3:0:8300::/80' encap bpf xmit obj '$REMOTE_OBJ' section lwt_xmit/tlv_selector dev '$VM03_SID_DEV' && \
     ip -6 route show 'fd00:a:3:0:8300::/80'"
