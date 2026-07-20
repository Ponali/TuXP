#!/bin/bash

clear

TARGET=/mnt/target
umount -R $TARGET >/dev/null 2>/dev/null || true
# lsblk
# read -p "disk to format: " DISK  # DISK=/dev/sda
# if [[ "$DISK" == *nvme* ]]; then
#     PART1="${DISK}p1"
#     PART2="${DISK}p2"
# else
#     PART1="${DISK}1"
#     PART2="${DISK}2"
# fi
DISK="/dev/$1"

# Wait for network
nm-online -q --timeout=30 || {
    echo "No network"
    exit 1
}

# Partition disk
echo PARTITION 0
parted -s $DISK mklabel gpt
bootPartSize="1MiB"
if [ -d /sys/firmware/efi ]; then
    bootPartSize="384MiB"
    echo PARTITION 20
    parted -s $DISK mkpart ESP fat32 0% "$bootPartSize"
    echo PARTITION 40
    parted -s "$DISK" set 1 esp on
    echo PARTITION 60
    mkfs.vfat -F32 ${DISK}1
else
    echo PARTITION 25
    parted -s $DISK mkpart primary 0% "$bootPartSize"
    echo PARTITION 50
    parted -s $DISK set 1 bios_grub on
fi
echo PARTITION 75
parted -s $DISK mkpart primary ext4 "$bootPartSize" 100%
echo PARTITION 100
yes | mkfs.ext4 ${DISK}2

# Mount target
mkdir -p $TARGET
mount ${DISK}2 $TARGET

# Install base Debian system
echo "STARTCOPYING"
TERM=linux debootstrap stable $TARGET
# TERM=linux is so that perl scripts with -T (taint) like dhcpcd-base (adduser) that apt has to install doesn't fuck up
# this weird ass while loop is so that if it fails (sometimes common) it will try again

# Generate fstab
cat > "$TARGET/etc/fstab" <<EOF
# /etc/fstab: static file system information.
#
# Use 'blkid' to print the universally unique identifier for a
# device; this may be used with UUID= as a more robust way to name devices
# that works even if disks are added and removed. See fstab(5).
#
# systemd generates mount units based on this file, see systemd.mount(5).
# Please run 'systemctl daemon-reload' after making changes here.
#
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
UUID=$(blkid -s UUID -o value ${DISK}2)  /  ext4  defaults,errors=remount-ro  0  1
EOF
if [ -d /sys/firmware/efi ]; then
cat >> "$TARGET/etc/fstab" <<EOF
UUID=$(blkid -s UUID -o value ${DISK}1)  /boot/efi  vfat  umask=0077  0  1
EOF
fi

# Bind mounts
mount --bind /dev $TARGET/dev
mount --bind /proc $TARGET/proc
mount --bind /sys $TARGET/sys
mount --bind /dev/pts $TARGET/dev/pts
if [ -d /sys/firmware/efi ]; then
    mkdir -p "$TARGET/boot/efi"
    mount "${DISK}1" "$TARGET/boot/efi"
    mount --bind /sys/firmware/efi/efivars \
        "$TARGET/sys/firmware/efi/efivars"
fi

# Install packages
GRUBPACK="grub-pc"
if [ -d /sys/firmware/efi ]; then
    GRUBPACK="grub-efi"
fi
chroot $TARGET bash -c "
export TERM=linux
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y -o APT::Status-Fd=1 -o APT::Acquire::Progress-Fd=1 \
    linux-image-amd64 $GRUBPACK \
    parted sudo network-manager \
    python3-tk yad ffmpeg \
    xfce4 xfce4-terminal firefox-esr fastfetch telnet

apt-get install -y --download-only kbd console-setup
dpkg --unpack /var/cache/apt/archives/kbd_*.deb
dpkg --unpack /var/cache/apt/archives/console-setup_*.deb

echo PLEASEWAIT Loading NetworkManager...
systemctl enable NetworkManager.service
"

# Install bootloader
echo PLEASEWAIT Installing GRUB...
mkdir -p $TARGET/usr/sbin/
cat > $TARGET/usr/sbin/update-grub <<'EOF'
#!/bin/sh
set -e
exec grub-mkconfig -o /boot/grub/grub.cfg "$@"
EOF
chown root:root $TARGET/usr/sbin/update-grub
chmod 755 $TARGET/usr/sbin/update-grub
if [ -d /sys/firmware/efi ]; then
    chroot $TARGET grub-install --target=x86_64-efi \
    --efi-directory=/boot/efi \
    --bootloader-id=debian \
    --recheck \
    "$DISK"
else
    chroot $TARGET grub-install --target=i386-pc "$DISK"
fi

# Configure bootloader
echo PLEASEWAIT Configuring GRUB...
GRUB_FILE=$TARGET/etc/default/grub
function setGRUBConfig {
    if grep -q "^$1=" "$GRUB_FILE"; then
        sed -i "s/^$1=.*/$1=$2/" "$GRUB_FILE"
    else
        echo "$1=$2" >> "$GRUB_FILE"
    fi
}
setGRUBConfig GRUB_TIMEOUT 0
setGRUBConfig GRUB_DISABLE_RECOVERY '"true"'

rm -f $TARGET/etc/grub.d/05_debian_theme
mkdir -p $TARGET/boot/grub/themes
cat > $TARGET/boot/grub/themes/hide.txt <<'EOF'
message-color: "#000000"
message-bg-color: "#000000"
EOF
setGRUBConfig GRUB_THEME boot/grub/themes/hide.txt
setGRUBConfig GRUB_CMDLINE_LINUX_DEFAULT '"quiet splash"'

chroot $TARGET update-grub

# root autologin
echo PLEASEWAIT Loading root autologin...
mkdir -p $TARGET/etc/systemd/system/getty@tty1.service.d
cat > $TARGET/etc/systemd/system/getty@tty1.service.d/override.conf <<'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I $TERM
EOF
chroot $TARGET bash -c "
systemctl set-default multi-user.target

systemctl disable lightdm 2>/dev/null || true
systemctl disable gdm3 2>/dev/null || true
systemctl disable sddm 2>/dev/null || true
"
mkdir -p $TARGET/root/
cat > $TARGET/root/.bash_profile << 'EOF'
if [ "$(tty)" == "/dev/tty1" ]; then
    clear
    cd /root/assets/gsetup
    xinit /bin/sh -c 'xfwm4 & exec python3 main.py' >/dev/null 2>/dev/null
fi
EOF
echo PLEASEWAIT Copying assets...
mkdir -p $TARGET/root/assets/
cp -r /root/assets/ $TARGET/root/

echo PLEASEWAIT Configuring root password...
chroot $TARGET bash -c '
passwd root < <(
    echo "root"
    echo "root"
    yes ''
) >/dev/null 2>/dev/null
'

echo FINISHED
sleep 1 # race condition
