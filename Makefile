BPF_CLANG ?= clang
BPF_CFLAGS ?= -O2 -g -Wall -Werror -target bpf

BPF_OBJ := build/srv6_tlv.bpf.o
BPF_NOLOG_OBJ := build/srv6_tlv_nolog.bpf.o
BPF_SRC := src/srv6_tlv.c

.PHONY: all build clean up attach normal skip ping tcpdump-vm7 tcpdump-vm07 tcpdump-ns4 tracelog bpf-stats-normal bpf-stats-skip vm04-overhead-normal vm04-overhead-skip down

all: build

build: $(BPF_OBJ)

$(BPF_OBJ): $(BPF_SRC)
	mkdir -p $(dir $@)
	$(BPF_CLANG) $(BPF_CFLAGS) -c $< -o $@

$(BPF_NOLOG_OBJ): $(BPF_SRC)
	mkdir -p $(dir $@)
	$(BPF_CLANG) $(BPF_CFLAGS) -DTLV_TRACE_SUCCESS=0 -c $< -o $@

up:
	scripts/up.sh

attach: build
	scripts/attach.sh

normal:
	scripts/scenario_normal.sh

skip:
	scripts/scenario_skip.sh

ping:
	ssh -F infra/ssh_config vm01 ping -c 1 10.5.0.6

tcpdump-vm7:
	scripts/tcpdump_vm07.sh

tcpdump-vm07: tcpdump-vm7

tcpdump-ns4: tcpdump-vm7

tracelog:
	scripts/tracelog.sh

bpf-stats-normal:
	@echo "BPF runtime stats are not supported by tlv-srv6-app v1" >&2
	@exit 1

bpf-stats-skip:
	@echo "BPF runtime stats are not supported by tlv-srv6-app v1" >&2
	@exit 1

vm04-overhead-normal:
	@echo "VM04 overhead measurement is not supported by tlv-srv6-app v1" >&2
	@exit 1

vm04-overhead-skip:
	@echo "VM04 overhead measurement is not supported by tlv-srv6-app v1" >&2
	@exit 1

down:
	scripts/down.sh

clean:
	rm -rf build
