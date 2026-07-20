# TuXP

This is a work-in-progress attempt at making a Linux-based operating system that is configured to look and feel exactly like Windows XP, sometimes down to the pixel.

To build, you should normally be able to run `build.sh` in any Debian installation (or maybe anything that has `dpkg` and `apt`). You must have these programs installed (if they aren't already):

- `gcc` for compiling ISOLINUX (and maybe other stuff later on in the future)
- `live-build` for making a Debian live ISO

The resulting ISO will most likely be in `build/live-image-amd64.hybrid.iso`.

**WARNING**: Please start using this on a virtual machine (if possible). This has almost only been tested on QEMU + libvirt under BIOS. You might lose your data when installing TuXP on a real machine, so please identify your disk through an existing Linux install or by its size in MiB, and be careful while using the installer. (Pressing Enter on the disk select will install immediately to simulate Windows XP's setup behavior.)

## Current known limitations

The installation process works like Windows XP, but only the first stages of the setup in text mode have been configured to look like Windows XP. The graphical setup, the OOBE, and the desktop are not configured to look like Windows XP.

### First/Second stage (Text mode setup)

The setup that runs in the first stage of installation expects the machine to be directly connected to the Internet without needing any user input or manual setup. For more information, check [Installing with a Wi-Fi connection](#installing-with-a-wi-fi-connection).

Currently, the setup script used only installs to a **disk** (e.g. `/dev/sda`, `/dev/vda` or `/dev/nvme0n1`), and not a partition (e.g. `/dev/sda2`, `/dev/vda1` or `/dev/nvme0n1p7`). These disks are also not converted into text the same way Windows XP does, i.e. shows `sda ... 40955 MB` instead of `40955 MB Disk 0 at Id 0 on bus 0 on atapi [MBR]`. When Windows XP would ask you for which partition/volume to install to, this would instead ask you which disk to install to, which means some text have changed from the original.

Due to limitations with how Linux handles the framebuffer and the graphics mode, trying to change the screen resolution might cause only the framebuffer to change resolution and not the actual display. Depending on what you run it on, it may pad or stretch to fit the GPU mode's resolution it started on. To accomodate this, the live ISO boots with the `video=720x400` kernel parameter, which sets the GPU mode to something close to 720x400 (this resolution corresponds to the 80x25 text mode on a 8+1x16 VGA font)

Some of the VGA text is not in text mode due to the nature of how Linux boots (thus a bit after GRUB/ISOLINUX), so this has been configured to use a converted bitmap font taken from SeaBIOS (`Uni2-SeaBiosVGA9x16.psf`). The SeaBIOS font has been used in QEMU and Bochs, and has some minor differences with other VGA fonts (like `console-setup`'s `Uni2-VGA16.psf` and in VMWare) if you compare screenshots. Thus, you will see the first part of the setup as how QEMU/SeaBIOS would show it. For best experience, please use QEMU or libvirt.

Usually, VGA hardware and all implementations of VGA by virtual machine software would add a 9th column to every glpyh when rendering characters in text mode (but having glyphs stored as 8x16). This quirk has been applied to the converted bitmap font.
If your virtual machine renders text mode VGA without this quirk (which is probably unlikely), you may see the VGA text become more spaced out.

### Installing with a Wi-Fi connection

If the machine you're using needs manual setup to connect (e.g. Wi-Fi SSID/Password), switch to another TTY (Ctrl+Shift+F4 to F12), and set up the network through NetworkManager/`nmcli` (if you don't see what you are typing, type `reset` then Enter), then go back to the TTY that the setup was on (Ctrl+Shift+F1 to F3). The rest of the installation after the setup script can work offline, but the Internet connection doesn't copy over - you will have to redo all the connection steps after the system has been fully installed.

## Miscellaneous notes

With this being based on Debian, this has support for UEFI, including [shim-powered Secure Boot](https://wiki.debian.org/SecureBoot) (which might need some troubleshooting). This has, however, not been thoroughly tested. I reccomend you use a BIOS machine if possible for best experience.