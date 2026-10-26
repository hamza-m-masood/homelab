# 0006: Aim the lab at AI infrastructure

Status: accepted

## Context

The lab is for my career, and the role I'm aiming at is AI infrastructure.
AI platforms run on the layers the lab already covers: Kubernetes on bare
metal, networking, distributed storage, GitOps. On top of those they do
three jobs of their own: share scarce accelerators between teams, serve
models, and move model weights and checkpoints around.

The nodes have no GPU, and the M910q Tiny has no slot for one.

## Decision

- Phases 1-4 (router, Talos, Cilium, Argo CD) stay as planned.
- Storage is Rook-Ceph ([0007](0007-rook-ceph.md)), tested with model
  weights and checkpoints as well as a Zeebe cluster.
- The Cilium WireGuard vs Istio ambient comparison is dropped. WireGuard is
  switched on with Cilium and its overhead measured once.
- Two new phases, neither needing a GPU:
  - **Scheduling:** Dynamic Resource Allocation with the upstream example
    driver, which advertises simulated GPUs; Kueue and JobSet for queues,
    quotas and all-or-nothing scheduling of multi-pod jobs.
  - **Inference:** the Gateway API Inference Extension routing to
    `llm-d-inference-sim` replicas (vLLM's API and metrics, no model),
    llama.cpp with a small model for real tokens, autoscaling on queue depth.
- The Go controller caches model weights on nodes ahead of scale-up.
- Failure drills: inject failures and compare an AI agent's diagnosis with
  mine.
- A GPU node waits until the inference phase works on simulators
  ([hardware](../hardware.md#upgrades)).

## Alternatives

- **Rent GPUs instead**: real hardware on demand, and worth it for a single
  benchmark. Loses the bare-metal, network and storage layers this lab
  exists for.
- **Keep the general platform plan**: service mesh comparisons and Camunda
  workloads are useful, but they're not what AI infrastructure work centres
  on.
- **Buy a GPU node now**: scheduling and routing can be learned without one,
  so the money goes where it first makes a difference.

## Consequences

- Hands-on covers the control layer: scheduling, routing, storage and
  operations. The fast data path of AI clusters (RDMA, InfiniBand, NCCL,
  multi-node training) isn't reachable on 1 GbE; that comes from reading or
  rented hardware.
- Simulated GPUs and model servers test control logic, not performance.
  Write-ups say which results came from simulators.
- A fourth node needs a port. All five on the hAP are used (WAN, three
  nodes, rescue), so a GPU node also means a VLAN-aware gigabit switch.
