# 0008: The gaming PC becomes the GPU node

Status: accepted

## Context

The AI infrastructure phases ([0006](0006-ai-infrastructure.md)) need a real
NVIDIA GPU for anything beyond simulators, and the minis have no slot for
one. My gaming PC is no longer used for games:

| | |
|---|---|
| CPU | AMD Ryzen 7 7700, 8 cores |
| RAM | 32 GB DDR5-6000 |
| GPU | NVIDIA RTX 5070, 12 GB (Blackwell) |
| Disk | 1 TB NVMe |
| Network | onboard 2.5 GbE |

## Decision

- It runs only Talos; Windows is wiped. It joins as `node4`, a worker, at
  `10.10.10.14` and `10.10.20.14`.
- It joins after Argo CD, so its NVIDIA components are managed from Git like
  everything else.
- It gets its own Image Factory schematic: NVIDIA's open GPU kernel modules
  and container toolkit (RTX 50 cards only work with the open modules), AMD
  microcode, Realtek network firmware.
- It is neither a control-plane node nor a Ceph OSD. etcd and storage stay on
  the three minis, so switching node4 off never touches quorum or data. Its
  NVMe holds container images and cached model weights.
- A small VLAN-aware switch behind hAP ether4 carries node3 and node4. Each
  switch port is set up like a hAP node port: VLAN 10 untagged, VLAN 20
  tagged.

## Alternatives

- **A used workstation with a used RTX 3060**: the plan before the PC was
  free. Roughly €400-500 for an older, slower card.
- **Dual boot with Windows**: needs a second disk and care with BitLocker and
  Secure Boot. Unnecessary once the PC is lab-only.
- **A fourth control-plane node**: four etcd members tolerate no more
  failures than three, and a node that gets switched off to save power
  shouldn't hold quorum.

## Consequences

- One consumer GPU, so no MIG: sharing it means time-slicing or MPS.
  Multi-GPU work (NVLink, NCCL) is out of reach.
- RTX 50 support on Linux is recent. Expect some driver debugging.
- node3 and node4 share ether4's 1 GbE link to the rest of the lab, and
  node4's 2.5 GbE port runs at 1 GbE.
- It draws far more power than a mini, around 350 W with the GPU busy. It
  can be switched off between experiments; Wake-on-LAN brings it back.
- The router config gains node4 when it joins: a DNS record, and a BGP peer
  if it announces LoadBalancer IPs.
