dd if=/dev/zero of=/dev/shm/tmpdisk.img bs=1M count=4096 status=progress

if [ "$1" == "bios" ]; then
    qemu-system-amd64 -cdrom build/live-image-amd64.hybrid.iso -m 2048 -enable-kvm -drive file=/dev/shm/tmpdisk.img,format=raw,if=virtio
elif [ "$1" == "uefi" ]; then
    qemu-system-amd64 -bios /usr/share/qemu/OVMF.fd -cdrom build/live-image-amd64.hybrid.iso -m 2048 -enable-kvm -drive file=/dev/shm/tmpdisk.img,format=raw,if=virtio
fi
