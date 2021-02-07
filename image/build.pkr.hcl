variable "livecd_url" {
  type        = string
  description = "Release URL of the livecd iso"
  default     = "https://cdimage.debian.org/debian-cd/10.8.0-live/amd64/iso-hybrid/debian-live-10.8.0-amd64-standard.iso"
}

locals {
  checksum_url = regex_replace(var.livecd_url, "/[^/]*$", "/SHA256SUMS")
}

source "virtualbox-iso" "debian" {
  guest_os_type = "Debian_64"
  iso_url = var.livecd_url
  iso_checksum = "file:${local.checksum_url}"
  disk_size = 4096
  memory = 4096
  ssh_username = "user"
  ssh_password = "live"
  boot_command = [
    "<enter><wait10><wait5>",
    "sudo apt-get update",
    " && sudo apt-get install -y openssh-server",
    " && sudo systemctl start ssh",
    "<enter>",
  ]
  shutdown_command = "sudo shutdown -P now"
  output_filename = "debian"
}

build {
  sources = ["sources.virtualbox-iso.debian"]

  provisioner "shell" {
    script = "setup.sh"
  }
}
