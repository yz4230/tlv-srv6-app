#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFRA_DIR="${ROOT_DIR}/infra"

cd "$INFRA_DIR"

if [[ ! -f id ]]; then
    ssh-keygen -t ed25519 -N "" -f id -C tlv-srv6 >/dev/null
fi
if [[ ! -f id.pub ]]; then
    ssh-keygen -y -f id >id.pub
fi

"${INFRA_DIR}/scripts/download-image.sh"

terraform init
terraform apply -auto-approve -var "ssh_public_key=$(<id.pub)"

for vm in vm01 vm02 vm03 vm04 vm05 vm06 vm07; do
    virsh -c "${LIBVIRT_URI:-qemu:///system}" send-key "tlv-srv6-${vm}" --codeset xt 28 >/dev/null || true
done

"${INFRA_DIR}/scripts/gen-conns.sh"
ansible all -m ansible.builtin.wait_for_connection
ansible-playbook site.yml
