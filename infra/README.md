# VM infrastructure

This directory contains the libvirt/Terraform and Ansible environment for the
TLV SRv6 BPF application.

The topology uses six VMs:

```text
vm01 -- nw1 -- vm02 -- nw2 -- vm03 -- nw3 -- vm04 -- nw4 -- vm05
                              |
                             nw5
                              |
                             vm06
```

`vm03` hosts the Gateway, Embedder, and Selector BPF SIDs. `scenario_normal.sh`
sends traffic through `vm06`; `scenario_skip.sh` uses a non-zero ARG in the
Embedder SID and skips `vm06`.

Runtime files generated in this directory, including Terraform state, SSH keys,
connection files, and downloaded QCOW2 images, are intentionally ignored by git.
