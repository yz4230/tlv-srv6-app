# VM infrastructure

This directory contains the libvirt/Terraform and Ansible environment for the
TLV SRv6 BPF application.

The topology uses seven VMs:

```text
vm01 -- nw1 -- vm02 -- nw2 -- vm07 -- nw6 -- vm03 -- nw3 -- vm04 -- nw4 -- vm05
                                                |
                                               nw5
                                                |
                                               vm06
```

Roles:

- `vm01`: IPv4 ping source for `10.4.0.5`.
- `vm02`: Gateway. It installs a reserved-SRH encap route with
  `ip-seg6-encap`.
- `vm07`: Embedder BPF SID. It writes `0` or `1` into the reserved SRH byte
  from the active SID ARG.
- `vm03`: Selector BPF SID. It reads the reserved byte and either sends traffic
  through `vm06` or skips it.
- `vm06`: waypoint used only by the normal path.
- `vm04`: End.DX4 egress SID for IPv4 delivery to `vm05`.
- `vm05`: IPv4 ping destination `10.4.0.5`.

`scenario_normal.sh` sends traffic through `vm06`. `scenario_skip.sh` uses a
non-zero ARG in the Embedder SID and skips `vm06`.

Runtime files generated in this directory, including Terraform state, SSH keys,
connection files, and downloaded QCOW2 images, are intentionally ignored by git.
