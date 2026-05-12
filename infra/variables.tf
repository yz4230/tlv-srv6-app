variable "libvirt_uri" {
  type    = string
  default = "qemu:///system"
}

variable "pool" {
  type    = string
  default = "default"
}

variable "name_prefix" {
  type    = string
  default = "tlv-srv6"
}

variable "image_path" {
  type    = string
  default = "images/debian-cloud.qcow2"
}

variable "ssh_public_key" {
  type    = string
  default = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITlvSrv6PlaceholderKeyDoNotUse tlv-srv6-placeholder"
}

variable "memory_gib" {
  type    = number
  default = 2
}

variable "vcpu" {
  type    = number
  default = 2
}
