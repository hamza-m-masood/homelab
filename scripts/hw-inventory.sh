#!/usr/bin/env bash
# Hardware inventory for a homelab node, run from a Linux live USB
# (Ubuntu desktop live works as-is). Read-only: it changes nothing.
#
#   curl -fsSL https://raw.githubusercontent.com/hamza-m-masood/homelab/main/scripts/hw-inventory.sh | sudo bash
#
# Prints what the Talos, storage and networking decisions depend on and
# keeps a copy in /tmp/hw-<serial>.txt. See docs/hardware.md.
set -uo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "run as root (sudo): dmidecode needs it" >&2
  exit 1
fi

have() { command -v "$1" >/dev/null 2>&1; }
section() { printf '\n== %s\n' "$1"; }
dmi() { dmidecode -s "$1" 2>/dev/null | head -n1; }

serial=$(dmi system-serial-number | tr -cd '[:alnum:]-')
out="/tmp/hw-${serial:-unknown}.txt"

{
  section "system"
  # On Lenovo, product-name is the machine type (e.g. 10T7...) and
  # version is the marketing name (e.g. ThinkCentre M720q).
  for key in system-manufacturer system-product-name system-version \
             system-serial-number baseboard-product-name bios-version bios-release-date; do
    printf '%-24s %s\n' "$key" "$(dmi "$key")"
  done

  section "firmware"
  if [[ -d /sys/firmware/efi ]]; then echo "boot mode: UEFI"; else echo "boot mode: legacy BIOS"; fi
  sb=$(od -An -t u1 /sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c 2>/dev/null | awk '{print $NF}')
  case "$sb" in 1) echo "secure boot: on" ;; 0) echo "secure boot: off" ;; *) echo "secure boot: unknown" ;; esac
  echo "tpm: $(sed 's/^/version /' /sys/class/tpm/tpm0/tpm_version_major 2>/dev/null || echo none)"
  # AMT adds a serial-over-LAN (KT) PCI device; the plain ME interface doesn't.
  if lspci 2>/dev/null | grep -qi 'Active Management Technology'; then
    echo "intel amt: present (vPro: out-of-band power and KVM)"
  else
    echo "intel amt: not detected (no vPro, or disabled in BIOS)"
  fi

  section "cpu"
  lscpu | grep -E '^(Model name|CPU\(s\)|Thread\(s\) per core|Core\(s\) per socket|CPU max MHz):'
  # aes/sha_ni matter for TLS (Istio ambient), avx2/avx512 for WireGuard's ChaCha20.
  echo "crypto flags: $(grep -m1 -w -o -E 'aes|sha_ni|avx2|avx512f' /proc/cpuinfo | sort -u | tr '\n' ' ')"

  section "memory"
  free -h | awk 'NR==2 {print "total visible: " $2}'
  dmidecode -t 16 2>/dev/null | grep -E 'Maximum Capacity|Number Of Devices'
  # One block per slot; empty slots read "Size: No Module Installed".
  dmidecode -t 17 2>/dev/null | grep -E '^\s+(Locator|Size|Type|Speed|Part Number):'

  section "disks"
  # The live USB itself shows up with TRAN=usb.
  lsblk -d -e 7,11 -o NAME,TRAN,ROTA,SIZE,MODEL,SERIAL
  if have smartctl; then
    for d in $(lsblk -d -n -e 7,11 -o NAME,TRAN | awk '$2 != "usb" {print $1}'); do
      echo "-- /dev/$d"
      smartctl -H -A "/dev/$d" | grep -Ei 'overall-health|percentage used|power_on_hours|power on hours|wear|data units written' || true
    done
  else
    echo "(smartctl not installed: skipping drive health)"
  fi

  section "pci"
  # NICs, Wi-Fi, NVMe/SATA controllers and the GPU (i915 extension or not).
  lspci -nn | grep -Ei 'ethernet|network|non-volatile|sata|raid|vga|display' || echo "(lspci not available)"

  section "network"
  for dev in /sys/class/net/*; do
    [[ -e $dev/device ]] || continue # skip virtual interfaces
    name=${dev##*/}
    driver=$(basename "$(readlink -f "$dev/device/driver")")
    speed=$(cat "$dev/speed" 2>/dev/null || echo -)
    printf '%-14s mac=%s driver=%s state=%s speed=%s\n' \
      "$name" "$(cat "$dev/address")" "$driver" "$(cat "$dev/operstate")" "$speed"
  done
} 2>&1 | tee "$out"

echo
echo "saved to $out"
