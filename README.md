# homelab

A bare-metal Kubernetes lab (three mini PCs and a GPU node), defined entirely in this repo and
rebuildable from scratch in about 20 minutes. It exists to practise the
layers below the ones I work with every day (bare metal, L2/L3 networking,
eBPF, self-run distributed storage, GitOps) and the jobs AI platforms add on
top: scheduling scarce accelerators, serving models, and moving model
weights around ([why](docs/adr/0006-ai-infrastructure.md)). Its real
workload is document processing for a small car import business, built with
Camunda's agentic orchestration ([0009](docs/adr/0009-real-workload.md)).

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
| Inference | Gateway API Inference Extension with my own routing plugin, vLLM, simulated vLLM servers, KEDA, Python load harness ([0010](docs/adr/0010-inference-at-scale.md)) |
| Workload | Camunda 8: agentic BPMN flows and document extraction for a car import business |
| Secrets | SOPS + age |
| DNS / TLS | `hamzatest.com` on Cloudflare, cert-manager, external-dns |

## Roadmap

- [ ] **0. Hardware inventory and BIOS**: [docs/hardware.md](docs/hardware.md). Inventory done; RAM going to 20 GB per node, data SSD deferred
- [x] **1. Router**: hAP ax2 as code (VLANs, DHCP, DNS, firewall, BGP, WireGuard, Wi-Fi). [Config](network/routeros/) applied to the real hAP: plan clean, Wi-Fi verified. BGP sessions follow in phase 3
- [ ] **2. Talos**: three-node HA control plane, VIP, Image Factory schematic. [Configs](talos/) written and validated in CI; install with the [first-boot runbook](docs/runbooks/talos-first-boot.md)
- [ ] **3. Cilium**: kube-proxy replacement, native routing, BGP to the hAP, Gateway API, Hubble. WireGuard on, overhead measured once
- [ ] **4. GitOps**: Argo CD manages everything; `task rebuild` under 20 minutes
- [ ] **5. Inference routing on simulators**: simulated vLLM replicas behind the Gateway API Inference Extension, no GPU needed. Round robin vs least queue vs prefix-cache-aware vs a routing plugin of my own, under replayed bursty traffic ([0010](docs/adr/0010-inference-at-scale.md))
- [ ] **6. Storage**: Rook-Ceph. How fast model weights load from it, what node loss does to checkpoints and to a Zeebe cluster
- [ ] **7. Camunda**: Camunda 8 through Argo CD, and the first document flow for the car import business, on a cloud model with test documents ([0009](docs/adr/0009-real-workload.md))
- [ ] **8. GPU node**: the old gaming PC joins as a Talos worker with NVIDIA's open kernel modules and container toolkit ([0008](docs/adr/0008-gpu-node.md)). Needs a VLAN switch
- [ ] **9. Serving on the GPU**: vLLM on the RTX 5070, the routing comparison repeated on real hardware, prefix caching and structured output measured, batching tuned from metrics, a mixed pool of two accelerator types. The document flow moves onto it, so real customer documents never leave the house
- [ ] **10. Autoscaling and cold starts**: scale on queue depth with KEDA, down to zero; a Go controller pre-caches model weights; time to serve a burst measured. The GPU node itself powers on with Wake-on-LAN when work arrives and shuts down when idle ([0011](docs/adr/0011-gpu-node-on-demand.md))
- [ ] **11. Model rollouts**: canary releases of a new model version with latency and evaluation gates, and automatic rollback
- [ ] **12. Multi-zone routing**: two zones with latency between them, locality routing with failover, a zone-loss drill under load
- [ ] **13. Scheduling**: Dynamic Resource Allocation with NVIDIA's driver, plus simulated GPUs to schedule across more than one; Kueue and JobSet for queues, quotas and all-or-nothing scheduling
- [ ] **14. Failure drills**: inject failures, compare an AI agent's diagnosis with mine. Scheduled around the live document flow

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
  workloads/          Camunda, model servers and test workloads
experiments/          hypothesis, method, Python harness and raw results per experiment
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
- [0009 A real workload: document processing for a car import business](docs/adr/0009-real-workload.md)
- [0010 Inference work aimed at serving at scale](docs/adr/0010-inference-at-scale.md)
- [0011 The GPU node is powered on demand](docs/adr/0011-gpu-node-on-demand.md)
