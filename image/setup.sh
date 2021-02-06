#!/bin/sh -eux

DISK=/dev/sda
ROOT=/mnt
POOL=main
BOOTSIZE=512M
POOLSIZE=2G
CODENAME=buster
ARCH=$(uname -r)
APTFLAGS="-y --no-install-recommends"


# Packer's shell provisioner does not have an option to use sudo.
if [ $(id -u) != 0 ]; then
    exec sudo "$0" "$@"
fi


# LIVECD ---------------------------------------------------------------------

export DEBIAN_FRONTEND=noninteractive

cat > /etc/apt/sources.list <<END
deb http://deb.debian.org/debian ${CODENAME} main contrib
deb http://deb.debian.org/debian ${CODENAME}-backports main contrib
END

apt-get update

# ZFS on Linux for the livecd environment. These packages are not installed
# on the image that we build. Just to use `zpool create` and `zfs create` on
# this livecd environment.
apt-get install ${APTFLAGS} dkms dpkg-dev linux-headers-${ARCH}
apt-get install ${APTFLAGS} -t ${CODENAME}-backports zfs-dkms
modprobe zfs
apt-get install ${APTFLAGS} -t ${CODENAME}-backports zfsutils-linux

# Tools for manual Debian installation.
apt-get install ${APTFLAGS} debootstrap gdisk


# DISK -----------------------------------------------------------------------

sgdisk -a1 -n1:24K:+1M        -t1:EF02 ${DISK}  # BIOS
sgdisk     -n2:0:+${BOOTSIZE} -t2:8300 ${DISK}  # Boot partition
sgdisk     -n3:0:+${POOLSIZE} -t2:8300 ${DISK}  # zpool

zpool create \
  -o ashift=12 \
  -O acltype=posixacl \
  -O canmount=off \
  -O compression=lz4 \
  -O mountpoint=none \
  -O relatime=on \
  -R ${ROOT} \
  ${POOL} \
  ${DISK}3

zfs create -o mountpoint=/ ${POOL}/debian

mkdir ${ROOT}/boot

# Boot partition needs special zpool settings to work. So, we just use ext4.
mkfs.ext4 ${DISK}2
mount     ${DISK}2 ${ROOT}/boot


# DEBIAN SETUP ---------------------------------------------------------------

debootstrap ${CODENAME} ${ROOT}

mount -t proc  none ${ROOT}/proc
mount -t sysfs none ${ROOT}/sys
mount --bind   /dev ${ROOT}/dev

chroot ${ROOT} ln -s /proc/self/mounts /etc/mtab

# Standard repositories plus backports (for ZFS).
cat > ${ROOT}/etc/apt/sources.list << END
deb     http://deb.debian.org/debian/          ${CODENAME}           main contrib
deb-src http://deb.debian.org/debian/          ${CODENAME}           main contrib
deb     http://deb.debian.org/debian/          ${CODENAME}-backports main contrib
deb-src http://deb.debian.org/debian/          ${CODENAME}-backports main contrib
deb     http://deb.debian.org/debian-security/ ${CODENAME}/updates   main
deb-src http://deb.debian.org/debian-security/ ${CODENAME}/updates   main
deb     http://deb.debian.org/debian/          ${CODENAME}-updates   main
deb-src http://deb.debian.org/debian/          ${CODENAME}-updates   main
END

chroot ${ROOT} apt-get update

# Need to set up at least one locale to suppress locale-related warnings.
chroot ${ROOT} apt-get install ${APTFLAGS} locales
sed -i "/en_US\.UTF-8/ s/^# *//" ${ROOT}/etc/locale.gen
chroot ${ROOT} locale-gen

# ZFS on Linux for the image environment.
chroot ${ROOT} apt-get install ${APTFLAGS} dpkg-dev linux-headers-${ARCH} linux-image-${ARCH}
chroot ${ROOT} apt-get install ${APTFLAGS} -t ${CODENAME}-backports spl spl-dkms zfs-initramfs zfsutils-linux

echo REMAKE_INITRD=yes > /etc/dkms/zfs.conf

# Bootloader.
chroot ${ROOT} apt-get install ${APTFLAGS} grub-pc
chroot ${ROOT} grub-install ${DISK}
chroot ${ROOT} update-grub

cat > ${ROOT}/etc/fstab << END
${DISK}2 /boot ext4  defaults 0 1
proc     /proc proc  defaults 0 0
sysfs    /sys  sysfs defaults 0 0
END

# Basic auth configuration.
chroot ${ROOT} apt-get install ${APTFLAGS} openssh-server sudo
chroot ${ROOT} passwd -d root

cat > ${ROOT}/etc/ssh/sshd_config << END
PermitRootLogin no
PasswordAuthentication no
ChallengeResponseAuthentication no
UsePAM yes
Subsystem sftp /usr/lib/openssh/sftp-server
END


# CLOUDINIT ------------------------------------------------------------------

# cloud-guest-utils is required for growpart.
chroot ${ROOT} apt-get install ${APTFLAGS} cloud-init cloud-guest-utils

chroot ${ROOT} systemctl enable cloud-init-local
chroot ${ROOT} systemctl enable cloud-init
chroot ${ROOT} systemctl enable cloud-config
chroot ${ROOT} systemctl enable cloud-final

# cloud-init (cc_growpart) cannot auto-detect zpool device for resizing. So,
# bake in the required configuration to the image.
cat > ${ROOT}/etc/cloud/cloud.cfg.d/10_zpool.cfg << END
growpart:
  devices:
    - ${DISK}3
END


# CLEANUP --------------------------------------------------------------------

umount ${ROOT}/boot
umount ${ROOT}/proc
umount ${ROOT}/sys
umount ${ROOT}/dev
umount ${ROOT}

zpool export -a
