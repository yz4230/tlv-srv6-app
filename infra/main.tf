terraform {
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
    }
  }
}

provider "libvirt" {
  uri = var.libvirt_uri
}

locals {
  image_path = abspath("${path.module}/${var.image_path}")
  networks   = { nw1 = {}, nw2 = {}, nw3 = {}, nw4 = {}, nw5 = {}, nw7 = {} }
  vms = {
    vm01 = {
      networks = ["nw1"]
    }
    vm02 = {
      networks = ["nw1", "nw2"]
    }
    vm03 = {
      networks = ["nw2", "nw3"]
    }
    vm04 = {
      networks = ["nw3", "nw4", "nw7"]
    }
    vm05 = {
      networks = ["nw4", "nw5"]
    }
    vm06 = {
      networks = ["nw5"]
    }
    vm07 = {
      networks = ["nw7"]
    }
  }
}

resource "libvirt_volume" "root" {
  for_each = local.vms

  name = "${var.name_prefix}-${each.key}.qcow2"
  pool = var.pool
  target = {
    format = {
      type = "qcow2"
    }
  }
  create = {
    content = {
      url = "file:///${local.image_path}"
    }
  }
}

resource "libvirt_cloudinit_disk" "init" {
  for_each = local.vms

  name = "${var.name_prefix}-${each.key}-init"
  user_data = templatefile("${path.module}/user.yaml", {
    ssh_public_key = var.ssh_public_key
  })
  meta_data = yamlencode({
    instance_id    = "${var.name_prefix}-${each.key}"
    local-hostname = each.key
  })
}

resource "libvirt_volume" "seed" {
  for_each = local.vms

  name = "${var.name_prefix}-${each.key}-seed"
  pool = var.pool
  create = {
    content = {
      url = libvirt_cloudinit_disk.init[each.key].path
    }
  }
}

resource "libvirt_network" "lab" {
  for_each = local.networks

  name      = "${var.name_prefix}-${each.key}"
  autostart = true
}

resource "libvirt_domain" "vm" {
  for_each = local.vms

  name        = "${var.name_prefix}-${each.key}"
  memory      = var.memory_gib
  memory_unit = "GiB"
  vcpu        = var.vcpu
  type        = "kvm"
  running     = true
  features    = { acpi = true, apic = { eoi = "on" } }
  cpu         = { mode = "host-passthrough" }
  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "q35"
    boot_devices = [{ dev = "hd" }]
  }
  devices = {
    disks = [
      {
        device = "disk"
        driver = { name = "qemu", type = "qcow2" }
        source = { file = { file = libvirt_volume.root[each.key].path } }
        target = { dev = "vda", bus = "virtio" }
      },
      {
        device = "cdrom"
        driver = { name = "qemu", type = "raw" }
        source = { file = { file = libvirt_volume.seed[each.key].path } }
        target = { dev = "sda", bus = "sata" }
      }
    ]
    interfaces = concat(
      [{
        source = { network = { network = "default" } }
        model  = { type = "virtio" }
        wait_for_ip = {
          source  = "lease"
          timeout = 300
        }
      }],
      [for nw in each.value.networks : {
        source = { network = { network = libvirt_network.lab[nw].name } }
        model  = { type = "virtio" }
      }]
    )
    consoles = [{ target = { type = "serial", port = "0" } }]
    videos   = [{ model = { type = "virtio", heads = "1", primary = "yes" } }]
  }
}

output "vm_names" {
  value = sort(keys(libvirt_domain.vm))
}

output "name_prefix" {
  value = var.name_prefix
}
