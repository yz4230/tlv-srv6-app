# tlv-srv6-app

SRv6 TLV service chain implemented with eBPF LWT XMIT.

Version 1 runs three BPF SIDs on `vm03`:

- `fd00:a:3:0:8100::/80` -> `lwt_xmit/tlv_gateway`
- `fd00:a:3:0:8200::/80` -> `lwt_xmit/tlv_embedder`
- `fd00:a:3:0:8300::/80` -> `lwt_xmit/tlv_selector`

The scenarios reserve SRH TLV space with an HMAC TLV. The Gateway rewrites that
reserved space so the first TLV slot is `type=0x42, len=1, value=0`. The
Embedder reads the first 16 bits of the active SID ARG and writes TLV value `0`
for zero ARG or `1` for non-zero ARG. The Selector reads the TLV, restores the
reserved space to padding before the packet leaves `vm03`, and advances one
segment for value `0`, or two segments for non-zero values to skip `vm06`.

## Requirements

- Linux with SRv6 and eBPF LWT support
- `clang`
- `iproute2`
- `bpftool` for `bpf_printk` logs
- Terraform
- Ansible
- libvirt/QEMU with the `default` network available
- `curl`, `jq`, `ssh`, and `scp`
- root privileges for VM networking and route setup

## Build

```bash
make clean
make build
```

This creates `build/srv6_tlv.bpf.o`.

## Run

```bash
make up
make attach
make normal
make skip
make down
```

The VM topology is managed under `infra/` with Terraform and Ansible:

```text
vm01 -- vm02 -- vm03 -- vm04 -- vm05
                  |
                 vm06
```

`make attach` uploads the BPF object to `vm03` and installs the Gateway,
Embedder, and Selector SID routes.

`make normal` installs this segment list on `vm02`:

```text
fd00:a:3:0:8100::,fd00:a:3:0:8200::,fd00:a:3:0:8300::,fd00:a:6::1,fd00:a:4::d4 hmac 1
```

The forward path is:

```text
vm01 -> vm02 -> vm03(Gateway -> Embedder -> Selector) -> vm06 -> vm03 -> vm04(decap) -> vm05
```

`make skip` installs this segment list on `vm02`:

```text
fd00:a:3:0:8100::,fd00:a:3:0:8200:1::,fd00:a:3:0:8300::,fd00:a:6::1,fd00:a:4::d4 hmac 1
```

The non-zero ARG on the Embedder SID causes the Selector to skip `vm06`:

```text
vm01 -> vm02 -> vm03(Gateway -> Embedder -> Selector skip) -> vm04(decap) -> vm05
```

Both scenarios send an ICMP echo request from `vm01` to `10.4.0.5` on `vm05`.

## Checks

Run tcpdump on `vm06` in another terminal before each scenario:

```bash
make tcpdump-vm06
```

`make normal` should capture a packet destined for `fd00:a:6::1`. `make skip`
should not capture one; use a timeout for that negative check:

```bash
timeout 3 make tcpdump-vm06
```

Trace logs are available from `vm03`:

```bash
make tracelog
```

Expected success logs appear in service order:

```text
tlv_gateway
tlv_embedder
tlv_selector
```

## Runtime Measurements

The old `bpf_stats` and `vm03_overhead` workflows from `minimum-srv6-app` are
not supported in v1. The current milestone is functional TLV service chaining
and normal/skip connectivity.

The symlinks `minimum-srv6-app` and `2026-03-29` are reference projects only and
are not used by the build or runtime scripts.
