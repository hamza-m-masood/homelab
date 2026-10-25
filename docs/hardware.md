# Hardware

| Device | Role | Notes |
|---|---|---|
| 3x Lenovo mini PC (model TBD) | Talos nodes, control plane + workloads | Inventory below |
| MikroTik hAP ax2 (RouterOS 7) | Lab router, switch, Wi-Fi, BGP peer | 1x WAN + 4x LAN, 1 GbE |
| Virgin Media gigabit hub | Home router, upstream of the hAP | Not managed by this repo |
| Netgear FS116 | Not used | 10/100 Mbps unmanaged; too slow for any lab traffic |

## Node inventory

Fill in from the output of `scripts/hw-inventory.sh` (raw output goes in
`docs/hardware/node-N.txt`).

| | node1 | node2 | node3 |
|---|---|---|---|
| Model (machine type) | TBD | TBD | TBD |
| Serial | TBD | TBD | TBD |
| CPU | TBD | TBD | TBD |
| RAM installed / max / free slots | TBD | TBD | TBD |
| Disk(s) | TBD | TBD | TBD |
| Free M.2 / 2.5" bay | TBD | TBD | TBD |
| PCIe riser possible | TBD | TBD | TBD |
| NIC (chip, driver) | TBD | TBD | TBD |
| NIC MAC | TBD | TBD | TBD |
| TPM / vPro (AMT) | TBD | TBD | TBD |

What the answers decide:

- **Disks and free slots**: Rook-Ceph needs a dedicated disk per node;
  Longhorn can live on the system disk. See the storage ADR (pending).
- **RAM**: Ceph wants about 4 GB per OSD on top of etcd, Cilium,
  Elasticsearch and Zeebe. 16 GB per node is tight, 32 GB comfortable.
- **PCIe riser** (M720q, M920q, P330 and similar): a dual-port NIC would
  give storage its own link instead of sharing one 1 GbE port.
- **CPU vendor / GPU**: which Talos extensions go into the image
  (`intel-ucode` or `amd-ucode`, `i915`).
- **vPro / AMT**: out-of-band power and remote KVM, effectively a BMC.
  Worth enabling for a lab with no SSH.
- **TPM 2.0**: Talos disk encryption sealed to the TPM (a later chapter;
  needs Secure Boot).

## Collecting it

### 1. Read the sticker (no tools)

The label underneath has **MT** (machine type, 4 characters such as `10T7`)
and **S/N**. The machine type is enough to look the box up on Lenovo PSREF,
which lists slots, maximum RAM and riser support.

### 2. BIOS settings (F1 at power-on)

While you're in there, set these on every node:

| Setting | Value | Why |
|---|---|---|
| After power loss | Power On | Nodes come back by themselves after an outage |
| Boot mode | UEFI only, CSM off | Talos boots UEFI |
| Secure Boot | Off (for now) | Talos Secure Boot needs a dedicated image; later chapter |
| USB boot | Enabled | Live USB now, Talos ISO next |
| Wake on LAN | Enabled | Bring nodes back from the router during node-loss tests |
| Intel AMT / vPro | Enabled, if present | Out-of-band power and KVM |

### 3. Run the inventory from a live USB

1. Write an Ubuntu desktop ISO (or any live Linux) to a USB stick.
2. Plug the node into a LAN port on the Virgin hub so it has internet.
3. Boot the stick (F12 for the boot menu), choose "Try Ubuntu", open a terminal:

   ```sh
   curl -fsSL https://raw.githubusercontent.com/hamza-m-masood/homelab/main/scripts/hw-inventory.sh | sudo bash
   ```

4. The output is also saved to `/tmp/hw-<serial>.txt`. Firefox on the live
   session is the easiest way to get it back here.

Run it on all three: used minis often have different RAM and disks even
when the model matches, and the MAC addresses are needed per node anyway.
The script only reads; nothing is written to the internal disks.
