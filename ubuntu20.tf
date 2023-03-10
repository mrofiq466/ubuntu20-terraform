terraform {
 required_version = ">= 0.13"
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.7.1"
    }
  }
}

# instance the provider
provider "libvirt" {
  uri = "qemu:///system"
}

resource "libvirt_pool" "test" {
  name = "test"
  type = "dir"
  path = "/tmp/test"
}

resource "libvirt_cloudinit_disk" "commoninit" {
  name           = "commoninit.iso"
  user_data      = data.template_file.user1_data.rendered
  network_config = data.template_file.network1_config.rendered
  pool           = libvirt_pool.test.name
}

data "template_file" "user1_data" {
  template = file("${path.module}/cloud_init.cfg")
}

data "template_file" "network1_config" {
  template = file("${path.module}/network_config.cfg")
}

# We fetch the latest ubuntu release image from their mirrors
resource "libvirt_volume" "ubuntu-vda" {
  name   = "ubuntu-vda.qcow2"
  pool   = libvirt_pool.test.name
  source = "https://cloud-images.ubuntu.com/releases/focal/release/ubuntu-20.04-server-cloudimg-amd64.img"
  format = "qcow2"
}

# Create the machine
resource "libvirt_domain" "testing" {
  name   = "testing"
  memory = "1024"
  vcpu   = "2"

  cloudinit = libvirt_cloudinit_disk.commoninit.id

  network_interface {
    network_name = "default"
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }

  disk {
    volume_id = libvirt_volume.ubuntu-vda.id
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}

# IPs: use wait_for_lease true or after creation use terraform refresh and terraform show for the ips of domain
