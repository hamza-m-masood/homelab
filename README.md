# homelab

A bare-metal Kubernetes lab (three mini PCs and a GPU node), defined entirely in this repo and
rebuildable from scratch in about 20 minutes. It exists to practise the
layers below the ones I work with every day (bare metal, L2/L3 networking,
eBPF, self-run distributed storage, GitOps) and the jobs AI platforms add on
top: scheduling scarce accelerators, serving models, and moving model
weights around ([why](docs/adr/0006-ai-infrastructure.md)).

Results get written up at [hamzamasood.dev](https://hamzamasood.dev).

## Stack

| Layer | Choice |
|---|---|
| Hardware | 3x Lenovo ThinkCentre M910q Tiny, a GPU node (Ryzen 7 7700, RTX 5070 12 GB), MikroTik hAP ax2 ([hardware](docs/hardware.md)) |
| Router | RouterOS 7, configured with OpenTofu |
| OS | Talos Linux: 3 control-plane nodes running workloads, plus the GPU node as a worker |
| Network | VLANs on one NIC, Cilium (kube-proxy replacement, BGP, Gateway API, Hubble) ([network](docs/network.md)) |
| GitOps | Argo CD |
| Storage | Rook-Ceph: block volumes, and S3 for model weights and checkpoints |
| Scheduling | Dynamic Resource Allocation (NVIDIA's driver, plus simulated GPUs for scale), Kueue, JobSet |
| Inference | Gateway API Inference Extension, vLLM, simulated vLLM servers |
| Secrets | SOPS + age |
| DNS / TLS | `hamzatest.com` on Cloudflare, cert-manager, external-dns |

## Roadmap

- [ ] **0. Hardware inventory and BIOS**: [docs/hardware.md](docs/hardware.md). Inventory done; RAM going to 20 GB per node, data SSD deferred
- [x] **1. Router**: hAP ax2 as code (VLANs, DHCP, DNS, firewall, BGP, WireGuard, Wi-Fi). [Config](network/routeros/) applied to the real hAP: plan clean, Wi-Fi verified. BGP sessions follow in phase 3
- [ ] **2. Talos**: three-node HA control plane, VIP, Image Factory schematic. [Configs](talos/) written and validated in CI; install with the [first-boot runbook](docs/runbooks/talos-first-boot.md)
- [ ] **3. Cilium**: kube-proxy replacement, native routing, BGP to the hAP, Gateway API, Hubble. WireGuard on, overhead measured once
- [ ] **4. GitOps**: Argo CD manages everything; `task rebuild` under 20 minutes
- [ ] **5. GPU node**: the old gaming PC joins as a Talos worker with NVIDIA's open kernel modules and container toolkit ([0008](docs/adr/0008-gpu-node.md)). Needs a VLAN switch
- [ ] **6. Storage**: Rook-Ceph. How fast model weights load from it, what node loss does to checkpoints and to a Zeebe cluster
- [ ] **7. Scheduling**: Dynamic Resource Allocation with NVIDIA's driver, plus simulated GPUs to schedule across more than one; Kueue and JobSet for queues, quotas and all-or-nothing scheduling
- [ ] **8. Inference**: vLLM on the RTX 5070 and simulated vLLM servers behind the Gateway API Inference Extension, autoscaling on queue depth. Cache-aware routing vs round robin, measured
- [ ] **9. A Go controller** that caches model weights on nodes before pods scale up; cold starts measured
- [ ] **10. Failure drills**: inject failures, compare an AI agent's diagnosis with mine

## Layout

Directories appear as each phase lands.

```
Taskfile.yaml         entry points: `task --list`
.mise.toml            pinned CLI versions: `mise install`
docs/                 hardware, network plan, decision records, runbooks
scripts/              helpers (hardware inventory, template filling, Talos config rendering)
network/routeros/     OpenTofu for the hAP ax2
talos/                Image Factory schematic, encrypted secrets, machine config patches
kubernetes/
  bootstrap/          applied once: Argo CD + root Application
  argocd/             ApplicationSets; Argo CD manages itself from here
  infrastructure/     one directory per component (cilium, cert-manager, storage, ...)
  workloads/          model servers and test workloads
experiments/          hypothesis, method, harness and raw results per experiment
controllers/          Go controller(s)
```

## Decisions

- [0001 Talos Linux](docs/adr/0001-talos-linux.md)
- [0002 Network design](docs/adr/0002-network-design.md)
- [0003 Argo CD](docs/adr/0003-argo-cd.md)
- [0004 RouterOS as code with OpenTofu](docs/adr/0004-routeros-as-code.md)
- [0005 Secrets with SOPS and age](docs/adr/0005-secrets-sops-age.md)
- [0006 Aim the lab at AI infrastructure](docs/adr/0006-ai-infrastructure.md)
- [0007 Rook-Ceph for storage](docs/adr/0007-rook-ceph.md)
- [0008 The gaming PC becomes the GPU node](docs/adr/0008-gpu-node.md)
