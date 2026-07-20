set -e

if findmnt -n -o OPTIONS -T "$PWD" | grep "nodev">/dev/null; then
  echo "the block device in $PWD is mounted with the 'nodev' option, which will make live-build fail."
  exit 1
fi

if ! [ -x "$(command -v lb)" ]; then
  echo "live-build is not installed."
  exit 1
fi

# compile dir
if ! [[ -d compiled ]]; then
  mkdir compiled
fi

# compile ISOLINUX/syslinux
sldir=(compiled/syslinux-*/)
if ((${#sldir[@]})) && [[ -d "${sldir[0]}" ]]; then
  echo "Using already built syslinux."
else
  sudo apt install dpkg-dev build-essential devscripts -y
  cd compiled
  apt source syslinux
  cd syslinux-*/
  python3 ../../syslinux.py
  make -j$(nproc) bios
  cd ../..
fi

buildExists=false
if [ -d build ]; then
  buildExists=true
else
  mkdir build
fi
cd build

if [ "$buildExists" == "true" ]; then
  sudo lb clean
fi

lb config \
    --distribution trixie \
    --architectures amd64 \
    --binary-images iso-hybrid \
    --debian-installer none \
    --memtest none \
    --iso-volume "TuXP [WIP]"

# package list
mkdir -p config/package-lists
cat > config/package-lists/custom.list.chroot << 'EOF'
kbd
console-setup
fbset
curl
parted
debootstrap
locales
network-manager
python3
python3-blessed
dosfstools
efibootmgr
EOF

# boot automatically (ISOLINUX)
CMDARGS="boot=live quiet loglevel=0 systemd.log_target=null rd.systemd.show_status=0 systemd.show_status=0 udev.log_level=0 vt.global_cursor_default=0 systemd.unit=multi-user.target video=720x400 noeject"

mkdir -p config/includes.binary/isolinux/
cat > config/includes.binary/isolinux/isolinux.cfg << 'EOF'
DEFAULT live
PROMPT 0
TIMEOUT 0

LABEL live
    MENU LABEL Debian Live
    KERNEL /live/vmlinuz
    APPEND initrd=/live/initrd.img __CMDARGS__
EOF
sed -i "s/__CMDARGS__/$CMDARGS/g" config/includes.binary/isolinux/isolinux.cfg

# boot automatically (GRUB)
mkdir -p config/includes.binary/boot/grub/
cat > config/includes.binary/boot/grub/grub.cfg << 'EOF'
set default=0
set timeout=0

menuentry "Debian Live" {
    clear
    echo "Setup is inspecting your computer's hardware configuration..."
    linux /live/vmlinuz __CMDARGS__
    initrd /live/initrd.img
}
EOF
sed -i "s/__CMDARGS__/$CMDARGS/g" config/includes.binary/boot/grub/grub.cfg

# mute reboot logs
mkdir -p config/includes.chroot_after_packages/etc/sysctl.d
cat > config/includes.chroot_after_packages/etc/sysctl.d/99-quiet.conf << 'EOF'
kernel.printk = 0 0 0 0
EOF

# autologin override
mkdir -p config/hooks/normal
cat > config/hooks/normal/030-root-shell.chroot <<'EOF'
#!/bin/sh
set -e
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/override.conf <<'EOF2'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --skip-login --autologin root --noissue --noclear %I $TERM
EOF2
EOF
mkdir -p config/includes.chroot_after_packages/root/
cat > config/includes.chroot_after_packages/root/.bash_profile << 'EOF'
if [ "$(tty)" == "/dev/tty1" ]; then
  clear
  echo -e "\e[?25l\nSetup is inspecting your computer's hardware configuration..."
  dmesg -n 1 >/dev/null 2>/dev/null
  cd /root/assets/setup/
  exec /usr/bin/python3 main.py
  sleep 1
fi
EOF
cat > config/hooks/live/010-console-mode.chroot << 'EOF'
#!/bin/bash

systemctl set-default multi-user.target

systemctl disable lightdm 2>/dev/null || true
systemctl disable gdm3 2>/dev/null || true
systemctl disable sddm 2>/dev/null || true
EOF
chmod +x config/hooks/live/010-console-mode.chroot

# set font
mkdir -p config/includes.chroot_before_packages/etc/default/
mkdir -p config/includes.chroot_after_packages/etc/default/
echo '
# CONFIGURATION FILE FOR SETUPCON

# Consult the console-setup(5) manual page.

ACTIVE_CONSOLES="/dev/tty[1-6]"

CHARMAP="UTF-8"

CODESET="Uni2"
FONTFACE="SeaBiosVGA"
FONTSIZE="9x16"

VIDEOMODE=
' > config/includes.chroot_before_packages/etc/default/console-setup
cp config/includes.chroot_before_packages/etc/default/console-setup config/includes.chroot_after_packages/etc/default/console-setup
cat > config/hooks/live/010-console-font.chroot << 'EOF'
#!/bin/bash
setupcon --save --verbose
EOF
chmod +x config/hooks/live/010-console-font.chroot

# initramfs boot message
mkdir -p config/includes.chroot_before_packages/etc/initramfs-tools/scripts/init-premount/
cat > config/includes.chroot_before_packages/etc/initramfs-tools/scripts/init-premount/00splash << 'EOF'
#!/bin/sh


PREREQ=""

prereqs()
{
    echo "$PREREQ"
}

case "$1" in
    prereqs)
        prereqs
        exit 0
        ;;
esac

. /scripts/functions

sleep 1

printf '\033c'

echo
echo "Setup is inspecting your computer's hardware configuration..."
EOF
chmod +x config/includes.chroot_before_packages/etc/initramfs-tools/scripts/init-premount/00splash

# patched ISOLINUX
mkdir -v -p binary
cp -v ../compiled/syslinux-*/bios/core/isolinux.bin binary/isolinux.bin
cat > config/hooks/normal/9999-custom-isolinux.hook.binary << 'EOF'
#!/bin/sh
set -e

ls .
cp -v isolinux.bin isolinux/isolinux.bin
EOF
chmod +x config/hooks/normal/9999-custom-isolinux.hook.binary


# copy assets
ASSETDIR=config/includes.chroot_after_packages/root/assets
if [ -d $ASSETDIR ]; then rm -rv $ASSETDIR; fi
cp -r ../assets $ASSETDIR/
mkdir -p config/includes.chroot_after_packages/usr/share/consolefonts/
mkdir -p config/includes.chroot_after_packages/etc/

# copy fonts
CONSOLEFONTS="config/includes.chroot_before_packages/usr/share/consolefonts"
rm -rvf $CONSOLEFONTS
mkdir -p $CONSOLEFONTS
gzip -1 -v -c ../vgaoem.psf > $CONSOLEFONTS/vgaoem.psf.gz
gzip -1 -v -c ../Uni2-SeaBiosVGA9x16.psf > $CONSOLEFONTS/Uni2-SeaBiosVGA16.psf.gz
cp -v $CONSOLEFONTS/Uni2-SeaBiosVGA16.psf.gz $CONSOLEFONTS/Uni2-SeaBiosVGA9x16.psf.gz

# message
(clear && echo -e "\e[?25l\nSetup is inspecting your computer's hardware configuration...") > config/includes.chroot_after_packages/etc/motd
cat > config/hooks/live/010-pam-motd-remove.chroot << 'EOF'
#!/bin/bash

sudo sed -Ei \
  '/^[[:space:]]*session[[:space:]].*pam_motd\.so/ s/^/#/' \
  /etc/pam.d/login
EOF
chmod +x config/hooks/live/010-pam-motd-remove.chroot

# sshx, for debugging
cat > config/hooks/live/010-sshx.chroot << 'EOF'
#!/bin/bash
curl -sSf https://sshx.io/get | sh
EOF
chmod +x config/hooks/live/010-sshx.chroot


sudo lb build # 2>&1 | tee build.txt | grep -i "fix-devnull\|mknod\|dev/null"
