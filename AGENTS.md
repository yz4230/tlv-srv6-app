# Repository Guidelines

## Project Structure & Module Organization

- `src/srv6_tlv.c` contains the BPF program source.
- `Makefile` defines the build and operational entry points.
- `scripts/` contains helpers for VM lifecycle, BPF attachment, captures,
  scenarios, and trace logs.
- `infra/` contains the Terraform/libvirt and Ansible topology. Host-specific
  variables live in `infra/host_vars/`.
- `build/` is generated output and should not be committed.
- `minimum-srv6-app` and `2026-03-29` are reference symlinks only; do not depend
  on them for normal work.

## Build, Test, and Development Commands

- `make build` compiles `src/srv6_tlv.c` to `build/srv6_tlv.bpf.o`.
- `make clean` removes generated build artifacts.
- `make up` provisions/configures the seven-VM SRv6 topology.
- `make attach` builds and attaches the Embedder and Selector BPF SIDs on
  `vm03` and `vm04`.
- `make normal` runs the path that should traverse `vm07`.
- `make skip` runs the path that should skip `vm07`.
- `make tcpdump-vm07` captures packets on `vm07`; use `timeout 3 make tcpdump-vm07`
  when validating the skip case.
- `make tracelog` reads BPF trace output from `vm03` and `vm04`.
- `make down` tears down the VM environment.

## Coding Style & Naming Conventions

Use the existing C style in `src/srv6_tlv.c`: two-space indentation, K&R braces,
short helper variables, and explicit bounds checks before packet access. Keep BPF
verifier constraints in mind: avoid unbounded loops, validate headers against
`data_end`, and keep log messages concise. Treat `-Wall -Werror` failures as
blocking.

Shell scripts use lowercase names with underscores, such as `scenario_normal.sh`.
Make targets should be short, hyphenated commands that wrap scripts.

## Testing Guidelines

There is no standalone unit test suite. Validate changes with:

1. `make build`
2. `make up`
3. `make attach`
4. `make normal`
5. `make skip`

For behavior changes, confirm packet paths with `make tcpdump-vm07` and inspect
BPF logs with `make tracelog`. Include commands run and observed results in PR
notes.

## Commit & Pull Request Guidelines

The current history uses short summaries, for example `first impl`. Keep commit
subjects concise and describe the concrete change. Pull requests should include
the SRv6/BPF behavior affected, validation commands run, and infrastructure
assumptions such as libvirt network availability or root privileges.

## Security & Configuration Tips

Do not commit Terraform state, SSH keys, QCOW2 images, or runtime connection
files under `infra/`. Keep host-specific configuration in `infra/host_vars/` and
avoid hard-coding local absolute paths in scripts.
