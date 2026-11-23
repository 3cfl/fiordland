#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

iso=$(ls -t out/*.iso 2>/dev/null | head -1)
mkdir -p vm
[[ -f vm/disk.qcow2 ]] || qemu-img create -q -f qcow2 vm/disk.qcow2 30G
[[ -f vm/vars.fd ]] || cp /usr/share/edk2/x64/OVMF_VARS.4m.fd vm/vars.fd

firmware=(-drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd
          -drive if=pflash,format=raw,file=vm/vars.fd)
boot=(-drive "file=$iso,media=cdrom,if=none,id=cd0,readonly=on" -device ide-cd,drive=cd0,bootindex=0)
display=(-display gtk,gl=on,grab-on-hover=on)
extra=()
audio=(-audiodev pipewire,id=snd -device intel-hda -device hda-duplex,audiodev=snd)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bios) firmware=(); shift ;;
    --disk) boot=(); shift ;;
    --share) extra+=(-virtfs "local,path=$PWD,mount_tag=fiordland,security_model=none,readonly=on"); shift ;;
    --headless) display=(-display egl-headless); audio=(); shift ;;
    --fresh) rm -f vm/disk.qcow2 vm/vars.fd; qemu-img create -q -f qcow2 vm/disk.qcow2 30G
             cp /usr/share/edk2/x64/OVMF_VARS.4m.fd vm/vars.fd; shift ;;
    *) break ;;
  esac
done
[[ ${#boot[@]} -gt 0 && -z "$iso" ]] && { echo "no iso in out/, run ./build.sh first"; exit 1; }

exec qemu-system-x86_64 \
  -enable-kvm -cpu host -smp 4 -m 8G -machine q35 \
  "${firmware[@]}" "${boot[@]}" \
  -drive file=vm/disk.qcow2,if=none,id=hd0 -device virtio-blk-pci,drive=hd0,bootindex=1 \
  -device virtio-vga-gl,xres=1600,yres=900 "${display[@]}" \
  -device qemu-xhci -device usb-tablet \
  -nic user,model=virtio-net-pci \
  -qmp unix:vm/qmp.sock,server,nowait \
  -device virtio-serial -chardev socket,path=vm/qga.sock,server=on,wait=off,id=qga0 \
  -device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0 \
  "${audio[@]}" "${extra[@]}" \
  "$@"
