# Hardware

| Device | Role | Notes |
|---|---|---|
| 3x Lenovo ThinkCentre M910q Tiny (machine type 10MV) | Talos nodes, control plane + workloads | Details below |
| MikroTik hAP ax2 (RouterOS 7) | Lab router, switch, Wi-Fi, BGP peer | 1x WAN + 4x LAN, 1 GbE |
| Lenovo ThinkPad X390 (Linux) | Admin laptop (`task`, `tofu`, `talosctl`), and the external client for benchmarks | Wired into hAP ether5 through the ThinkPad Ethernet Extension Adapter |
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
network port.

## Upgrades (deferred)

Not bought yet, on cost. Router, Talos, Cilium and Argo CD fit in 8 GB per
node. Revisit before the storage phase: on 8 GB, that phase most likely uses
Longhorn on the boot disk rather than Rook-Ceph.

| Per node | Why |
|---|---|
| 2x 16 GB DDR4 SODIMM, non-ECC, 2133 MT/s or faster | 8 GB fits Talos, Cilium and Argo CD, not storage plus Elasticsearch plus Zeebe (roughly 10-14 GB per node) |
| 1x M.2 2280 NVMe, 512 GB-1 TB, single-sided, in the SSD2 slot | Data disk for Ceph or Longhorn; Talos stays on the boot disk. 1 GbE caps replicated writes at ~110 MB/s, so NVMe vs SATA doesn't matter here |

The second slot may need an M.2 screw or clip; the first slot uses a blue
plastic clip.

The drive choice matters if Rook-Ceph is the storage pick:

- **Consumer NVMe:** fine for Longhorn. Slow under Ceph's synchronous writes,
  because there is no power-loss protection.
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
