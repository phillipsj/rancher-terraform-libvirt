terraform {
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

resource "libvirt_volume" "tumbleweed" {
  name   = "tumbleweed"
  pool   = "default"
  source = "http://download.opensuse.org/tumbleweed/appliances/openSUSE-Tumbleweed-JeOS.x86_64-OpenStack-Cloud.qcow2"
  format = "qcow2"
}

resource "libvirt_volume" "rancher" {
  name           = "rancher"
  base_volume_id = libvirt_volume.tumbleweed.id
  size = 10737418240
}

data "template_file" "user_data" {
  template = file("${path.module}/cloud_init.cfg")
}

data "template_file" "network_config" {
  template = file("${path.module}/network_config.cfg")
}

# for more info about paramater check this out
# https://github.com/dmacvicar/terraform-provider-libvirt/blob/master/website/docs/r/cloudinit.html.markdown
# Use CloudInit to add our ssh-key to the instance
# you can add also meta_data field
resource "libvirt_cloudinit_disk" "commoninit" {
  name           = "commoninit.iso"
  user_data      = data.template_file.user_data.rendered
  network_config = data.template_file.network_config.rendered
}

# Create the machine
resource "libvirt_domain" "rancher" {
  name   = "rancher"
  memory = "4096"
  vcpu   = 2


  cloudinit = libvirt_cloudinit_disk.commoninit.id

  network_interface {
    bridge = "br0"
    hostname = "rancher"
  }

  # IMPORTANT: this is a known bug on cloud images, since they expect a console
  # we need to pass it
  # https://bugs.launchpad.net/cloud-images/+bug/1573095
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
    volume_id = libvirt_volume.rancher.id
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}
