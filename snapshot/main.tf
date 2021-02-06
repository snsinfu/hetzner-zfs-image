resource "hcloud_server" "main" {
  name        = "debian"
  location    = "fsn1"
  server_type = "cx11"
  image       = "debian-10"
  rescue      = "linux64"
  ssh_keys    = [hcloud_ssh_key.temporary.id]
}

resource "hcloud_ssh_key" "temporary" {
  name       = "Temporary key"
  public_key = file("_sshkey.pub")
}

output "ip" {
  value = hcloud_server.main.ipv4_address
}

output "server_id" {
  value = hcloud_server.main.id
}
