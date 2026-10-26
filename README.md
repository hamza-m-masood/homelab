# homelab

A three-node bare-metal Kubernetes lab, defined entirely in this repo and
rebuildable from scratch in about 20 minutes. It exists to practise the
layers below the ones I work with every day: bare metal, L2/L3 networking,
eBPF, self-run distributed storage, and GitOps.

Results get written up at [hamzamasood.dev](https://hamzamasood.dev).

## Stack

| Layer | Choice |
|---|---|
| Hardware | 3x Lenovo ThinkCentre M910q Tiny, MikroTik hAP ax2 ([hardware](docs/hardware.md)) |
| Router | RouterOS 7, configured with OpenTofu |
| OS | Talos Linux, 3 control-plane nodes running workloads |
| Network | VLANs on one NIC, Cilium (kube-proxy replacement, BGP, Gateway API, Hubble) ([network](docs/network.md)) |
| GitOps | Argo CD |
| Storage | Longhorn or Rook-Ceph, decided at the storage phase (Rook-Ceph needs a RAM upgrade) |
| Secrets | SOPS + age |
| DNS / TLS | `hamzatest.com` on Cloudflare, cert-manager, external-dns |

## Roadmap

- [ ] **0. Hardware inventory and BIOS**: [docs/hardware.md](docs/hardware.md). Inventory done; RAM and data SSD upgrades deferred on cost
- [x] **1. Router**: hAP ax2 as code (VLANs, DHCP, DNS, firewall, BGP, WireGuard, Wi-Fi). [Config](network/routeros/) applied to the real hAP: plan clean, Wi-Fi verified. BGP sessions follow in phase 3
- [ ] **2. Talos**: three-node HA control plane, VIP, Image Factory schematic. [Configs](talos/) written and validated in CI; install with the [first-boot runbook](docs/runbooks/talos-first-boot.md)
- [ ] **3. Cilium**: kube-proxy replacement, native routing, BGP to the hAP, Gateway API, Hubble
- [ ] **4. GitOps**: Argo CD manages everything; `task rebuild` under 20 minutes
- [ ] **5. Storage**: distributed storage, Zeebe and Elasticsearch as the stateful test subjects, node-loss tests
- [ ] **6. Encryption**: Cilium WireGuard vs Istio ambient mTLS, throughput, latency and failure behaviour
- [ ] **7. A Go controller** for something the lab needs

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
  workloads/          stateful test subjects
experiments/          hypothesis, method, harness and raw results per experiment
controllers/          Go controller(s)
```

## Decisions

- [0001 Talos Linux](docs/adr/0001-talos-linux.md)
- [0002 Network design](docs/adr/0002-network-design.md)
- [0003 Argo CD](docs/adr/0003-argo-cd.md)
- [0004 RouterOS as code with OpenTofu](docs/adr/0004-routeros-as-code.md)
- [0005 Secrets with SOPS and age](docs/adr/0005-secrets-sops-age.md)
