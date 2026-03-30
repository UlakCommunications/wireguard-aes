#!/bin/bash
# Install kernel 5.15.0-173-generic required by the pre-built wireguard.ko.
# Vagrant reboots automatically after this script (reboot: true in Vagrantfile).
set -euo pipefail

KERNEL="5.15.0-173-generic"

echo "==> Current kernel: $(uname -r)"
if [ "$(uname -r)" = "$KERNEL" ]; then
    echo "==> Already on $KERNEL, skipping."
    exit 0
fi

echo "==> Installing kernel $KERNEL and required packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -y \
    linux-image-${KERNEL} \
    linux-modules-${KERNEL} \
    linux-modules-extra-${KERNEL} \
    wireguard-tools \
    iproute2 \
    iputils-ping \
    iperf3

# Set GRUB to boot into the new kernel
update-grub 2>/dev/null || true

SUBMENU_POS=$(awk '
  /submenu.*Advanced options/{ in_sub=1; pos=0; next }
  in_sub && /menuentry.*'"${KERNEL}"'/ && !/recovery/ { print pos; exit }
  in_sub && /menuentry / { pos++ }
' /boot/grub/grub.cfg 2>/dev/null || echo "")

if [ -n "$SUBMENU_POS" ]; then
    GRUB_ENTRY="1>${SUBMENU_POS}"
else
    GRUB_ENTRY="Advanced options for Ubuntu>Ubuntu, with Linux ${KERNEL}"
fi

sed -i "s|^GRUB_DEFAULT=.*|GRUB_DEFAULT=\"${GRUB_ENTRY}\"|" /etc/default/grub
update-grub

echo "==> GRUB_DEFAULT set to: $GRUB_ENTRY"
echo "==> Kernel $KERNEL installed. Vagrant will reboot now."
