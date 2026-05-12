#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

mapfile -t names < <(terraform output -json vm_names | jq -r '.[]')

name_prefix="$(terraform output -raw name_prefix 2>/dev/null || true)"
name_prefix="${name_prefix:-tlv-srv6}"

declare -A macs=()
for name in "${names[@]}"; do
    domain="${name_prefix}-${name}"
    domiflist="$(virsh -c "${LIBVIRT_URI:-qemu:///system}" domiflist "$domain")"
    macs["$name"]="$(awk '$3 == "default" { print tolower($5); exit }' <<<"$domiflist")"
    if [[ -z "${macs[$name]}" ]]; then
        echo "missing management MAC for $domain" >&2
        exit 1
    fi
done

declare -A ips=()
deadline=$((SECONDS + ${LEASE_TIMEOUT:-300}))

while ((SECONDS < deadline)); do
    declare -A lease_ips=()
    while read -r mac ip; do
        [[ -n "$mac" && -n "$ip" ]] || continue
        lease_ips["$mac"]="${ip%/*}"
    done < <(
        virsh -c "${LIBVIRT_URI:-qemu:///system}" net-dhcp-leases default |
            awk 'NR > 2 && $3 != "" { print tolower($3), $5 }'
    )

    missing=0
    for name in "${names[@]}"; do
        ip="${lease_ips[${macs[$name]}]:-}"
        if [[ -z "$ip" ]]; then
            missing=1
            break
        fi
        ips["$name"]="$ip"
    done

    if [[ "$missing" -eq 0 ]]; then
        break
    fi
    sleep 2
done

for name in "${names[@]}"; do
    if [[ -z "${ips[$name]:-}" ]]; then
        echo "missing DHCP lease for $name on libvirt default network" >&2
        exit 1
    fi
done

for name in "${names[@]}"; do
    cat <<EOF
Host ${name}
  HostName ${ips[$name]}
  User debian
  IdentityFile ${ROOT_DIR}/id
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  LogLevel ERROR

EOF
done >ssh_config

{
    echo "[vms]"
    printf '%s\n' "${names[@]}"
} >inventory.ini
