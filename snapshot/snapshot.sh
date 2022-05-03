#!/bin/sh -eu

server_id="$1"

curl -f \
  -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${HCLOUD_TOKEN}" \
  -d @- \
  "https://api.hetzner.cloud/v1/servers/${server_id}/actions/create_image" \
<< END
{
  "description": "Debian 11 ZFS",
  "type": "snapshot",
  "labels": {
    "image": "debian-11-zfs"
  }
}
END
