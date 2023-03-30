# Hetzner Debian ZFS image

Packer and Terraform scripts to create a reusable Hetzner cloud image that
boots Debian on ZFS root.

- [Usage](#usage)
- [How it works](#how-it-works)
- [License](#license)


## Usage

### Create a local image

Requirements: Packer and VirtualBox.

```console
$ cd image
$ make
...
$ ls debian.img
debian.img
```

The `make` command builds a raw disk image. Packer emulates key input to the
virtual machine console to bootstrap installation, so do not touch mouse nor
keyboard until packer sshs into the machine.

You may need to change livecd version in `image/build.pkr.hcl` to the latest
release. Otherwise, packer fails to download the livecd iso because Debian
project may delete old livecd images.


### Tranfer to Hetzner cloud

Requirements: Terraform, curl and Hetzner Cloud API token.

```console
$ cd snapshot
$ export HCLOUD_TOKEN=...
$ make
...
$ make clean
```

The `make` command spins up a rescue-mode CX11 instance on the Hetzner Cloud,
sshs into the instance and transfers the image to the main disk of the
instance. Then, it takes a snapshot of the image. You need to `make clean`
yourself to destroy the server.

The size of the snapshot is ~900MB. The storage cost then is ~0.01 €/month.


### Using the image

The image is labeled with `image`=`debian-11-zfs`. You may want to use this
label to select the image in a Terraform configuration.

The image forbids root login and password authentication. You should supply the
following cloudinit configuration or similar to the instance as a *user data*:

```yaml
#cloud-config

timezone: UTC

system_info:
  default_user:
    name: hetzner
    shell: /bin/bash
    sudo: "ALL=(ALL) NOPASSWD: ALL"
```

This will create non-root user `hetzner`. Public keys will be injected to this
user. You will see ZFS dataset in the created instance:

```console
$ df -h
Filesystem      Size  Used Avail Use% Mounted on
udev            958M     0  958M   0% /dev
tmpfs           195M  3.0M  192M   2% /run
main/debian      37G  752M   36G   3% /
tmpfs           974M     0  974M   0% /dev/shm
tmpfs           5.0M     0  5.0M   0% /run/lock
tmpfs           974M     0  974M   0% /sys/fs/cgroup
/dev/sda2       488M   49M  404M  11% /boot
$ sudo zfs list
NAME          USED  AVAIL     REFER  MOUNTPOINT
main          753M  35.7G       96K  none
main/debian   752M  35.7G      752M  /
```


## How it works

The packer script installs [Debian root-on-zfs][root-on-zfs] to a local virtual
machine by chrooting from a livecd shell. The Makefile uses `vbox-img` to
convert virtual hard disk to raw disk image. Then, `snapshot` scripts boot a
rescue linux system on a cloud instance and write the disk image directly to
the instance main disk. The snapshot of the instance then works as a Debian
ZFS image.

Booting an instace based on the created image runs first-boot sequence
including cloud-init, which automatically configures the system just like other
official images (including the auto-configured root password and injected SSH
pubkeys).

[root-on-zfs]: https://openzfs.github.io/openzfs-docs/Getting%20Started/Debian/Debian%20Buster%20Root%20on%20ZFS.html


## License

MIT license.
