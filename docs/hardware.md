# Hardware

| Device | Role | Notes |
|---|---|---|
| 3x Lenovo ThinkCentre M910q Tiny (machine type 10MV) | Talos nodes, control plane + workloads | Details below |
| MikroTik hAP ax2 (RouterOS 7.25) | Lab router, switch, Wi-Fi, BGP peer | 1x WAN + 4x LAN, 1 GbE. Second-hand with an unknown password and a disabled reset button; reinstalled with Netinstall |
| Lenovo ThinkPad X390 (Omarchy/Arch Linux, NetworkManager) | Admin laptop (`task`, `tofu`, `talosctl`), and the external client for benchmarks | Wired into hAP ether5 through a USB Ethernet adapter (`enp0s20f0u4`) |
| Virgin Media gigabit hub | Home router, upstream of the hAP | Not managed by this repo |
| Netgear FS116 | Not used | 10/100 Mbps unmanaged; too slow for any lab traffic |

## Nodes

All three are the same model. As found:

| | |
|---|---|
| CPU | Intel Core i5-6500, 4 cores / 4 threads, 3.2-3.6 GHz. AES-NI and AVX2, no AVX-512 |
| RAM | 8 GB: 2x 4 GB DDR4-2133 SODIMM. Both slots used; 32 GB maximum |
| Boot disk | 256 GB M.2 NVMe (SK hynix BC711 or Intel, varies per box) |
| Free storage slots | Second M.2 2280 slot (labelled "SATA/NVMe SSD2", under the bottom cover); 2.5" SATA bay on top (cable present, drive tray possibly missing) |
| NIC | Intel I219-LM, 1 GbE (`e1000e`) |
| Other | TPM 2.0, Intel 8265 Wi-Fi (unused), HD Graphics 530, 65 W power adapter |
| Firmware | UEFI, Secure Boot off, BIOS M1AKT36A (2018) |
| Intel AMT | Not detected, but likely available: Q270 chipset + I219-LM + a vPro-capable CPU |

RAM and both M.2 slots are under the bottom cover (top cover off first, then
the bottom cover).

| Node | hAP port | MAC |
|---|---|---|
| node1 | ether2 | `6c:4b:90:62:8c:3e` |
| node2 | ether3 | `6c:4b:90:64:61:71` |
| node3 | ether4 | from the router's DHCP leases on first boot |

Label the boxes to match. Each box also has its MAC on a sticker next to the
network port. The MACs are for Wake-on-LAN; the Talos config doesn't use
them (it finds the NIC by driver).

## Upgrades

RAM: one 16 GB DDR4 SODIMM (2Rx8) per node, next to one of the existing
4 GB sticks, for 20 GB. That fits everything on the roadmap with Ceph's
memory tuned down ([0007](adr/0007-rook-ceph.md)). Which stick is in which
box gets recorded here once each has passed MemTest86+. Swap one node at a
time; the cluster keeps quorum on the other two.

Deferred, on cost:

| What | Why |
|---|---|
| Per node: 1x M.2 2280 NVMe, 512 GB-1 TB, single-sided, in the SSD2 slot | A dedicated Ceph disk. Ceph starts on the free space of the boot disks; this is for when that's too small or too slow. 1 GbE caps replicated writes at ~110 MB/s, so NVMe vs SATA doesn't matter here |
| One GPU node: a used desktop with an NVIDIA card, 12 GB of VRAM or more | Real GPU scheduling and model serving ([0006](adr/0006-ai-infrastructure.md)), after the inference phase works on simulators. The M910q Tiny has no slot for a graphics card. Joins as a fourth Talos node, with NVIDIA's drivers as Talos system extensions. The hAP has no free port, so it also needs a VLAN-aware gigabit switch |

The second slot may need an M.2 screw or clip; the first slot uses a blue
plastic clip.

The drive choice matters for Ceph:

- **Consumer NVMe** (what the boot disks are): works, but slow under Ceph's
  synchronous writes, because there is no power-loss protection.
- **Used enterprise M.2 2280 with power-loss protection** (Kingston
  DC1000B/DC2000B, Micron 7400/7450 PRO): Ceph behaves like it does on
  servers. They run hotter.

## BIOS settings (F1 at power-on)

| Setting | Value | Why |
|---|---|---|
| After power loss | Power On | Nodes come back by themselves after an outage |
| Boot mode | UEFI only, CSM off | Talos boots UEFI |
| Secure Boot | Off (for now) | Talos Secure Boot needs a dedicated image; later chapter |
| USB boot | Enabled | Talos ISO |
| Wake on LAN | Enabled | Bring nodes back from the router during node-loss tests |
| Intel AMT | Enabled, after a BIOS/ME update | Out-of-band power and remote KVM: effectively a BMC |

The BIOS is from 2018. Update BIOS and Intel ME firmware from Lenovo's
support site (search for machine type 10MV) before enabling AMT, which has
had serious vulnerabilities fixed in later ME releases.

## Re-running the inventory

`scripts/hw-inventory.sh` prints everything above from a Linux live USB. It
is read-only.

```sh
curl -fsSL https://raw.githubusercontent.com/hamza-m-masood/homelab/main/scripts/hw-inventory.sh | sudo bash
```

To get the output off a machine that only has a shell:

```sh
cat /tmp/hw-*.txt | curl -sS -w '\n' --data-binary @- https://paste.rs
```

That prints a URL. The paste is public until deleted
(`curl -X DELETE <url>`).
