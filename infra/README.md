# VM infrastructure

This directory contains the libvirt/Terraform and Ansible environment for the
TLV SRv6 BPF application.

The topology uses seven VMs:

```text
vm01 -- nw1 -- vm02 -- nw2 -- vm03 -- nw3 -- vm04 -- nw4 -- vm05 -- nw5 -- vm06
                                                |
                                               nw7
                                                |
                                               vm07
```

Roles:

- `vm01`: IPv4 ping source for `10.5.0.6`.
- `vm02`: Gateway. It installs a reserved-SRH encap route with
  `ip-seg6-encap`.
- `vm03`: Embedder BPF SID. It writes `0` or `1` into the reserved SRH byte
  from the active SID ARG.
- `vm04`: Selector BPF SID. It reads the reserved byte and either sends traffic
  through `vm07` or skips it.
- `vm07`: waypoint used only by the normal path.
- `vm05`: End.DX4 egress SID for IPv4 delivery to `vm06`.
- `vm06`: IPv4 ping destination `10.5.0.6`.

`scenario_normal.sh` sends traffic through `vm07`. `scenario_skip.sh` uses a
non-zero ARG in the Embedder SID and skips `vm07`.

Runtime files generated in this directory, including Terraform state, SSH keys,
connection files, and downloaded QCOW2 images, are intentionally ignored by git.
