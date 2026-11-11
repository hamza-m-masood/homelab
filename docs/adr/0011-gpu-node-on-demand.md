# 0011: The GPU node is powered on demand

Status: accepted

## Context

The GPU node ([0008](0008-gpu-node.md)) draws around 350 W busy and roughly
50-70 W idle. Always on, idle alone is about 500 kWh and €150 a year, and
it would mostly be waiting: the car import paperwork
([0009](0009-real-workload.md)) arrives a few times a week and nothing about
it is urgent. A wait of a few minutes before extraction starts is fine.

0008 already plans to switch node4 off between experiments and bring it back
with Wake-on-LAN. That was manual. The document flow needs it to happen by
itself, and doing it automatically is the node-level half of the
scale-to-zero work in [0010](0010-inference-at-scale.md) phase 3.

## Decision

- node4 is off by default. Demand wakes it, idleness shuts it down.
- Model servers on node4 scale to zero with KEDA on queue depth, as planned
  in 0010.
- node4 is tainted so that only GPU workloads land on it. Nothing else should
  keep it awake or be stranded when it goes off.
- A Go controller in `controllers/` handles node power:
  - **Wake:** a pod that tolerates node4's taint is Pending while node4 is
    off. The controller sends a Wake-on-LAN magic packet to node4's MAC as a
    broadcast on the mgmt VLAN. It runs on the minis with host networking,
    so the packet stays on VLAN 10 and the cluster needs no router
    credentials. node4 is uncordoned once it's Ready.
  - **Shut down:** no pods using node4's GPU for 15 minutes. The controller
    cordons and drains node4, then shuts it down through the Talos API. It
    uses Talos's Kubernetes API access feature, which gives a ServiceAccount
    the `os:operator` role, so no talosconfig is stored in the cluster.
  - Wakes are rate-limited and failures surface as events and metrics, so a
    node that won't start doesn't get magic packets forever.
- On the Camunda side, the extraction worker treats an unreachable model
  server as a retryable failure: Zeebe job retries with a backoff long enough
  to cover boot plus model load. If the GPU still isn't serving after that,
  the job becomes an incident and the documents wait for a person, as they
  would anyway.
- Measured as part of 0010 phase 3: time from the first queued document to
  the first token (power-on, boot, driver load, model load from the NVMe
  cache), and energy per processed car from the power draw.

## Alternatives

- **Always on**: no cold start, and about €150 a year in idle power for a
  machine that's mostly waiting.
- **A fixed daily window**: a BIOS wake alarm or a cron job starts it at, say,
  18:00, and it shuts down after the batch. Simple and predictable, but
  documents wait up to a day, and it teaches nothing about scaling from zero.
  It's the fallback if wake-on-demand proves unreliable.
- **The cluster autoscaler or Karpenter**: built for cloud APIs that create
  and delete machines. A bare-metal provider that powers a fixed machine on
  and off is little more than this controller with more moving parts.
- **A MacBook Pro M2 Pro instead of the gaming PC**: Talos doesn't run on
  Apple Silicon, and Linux VMs on macOS get no GPU, so it can't be a node. It
  could serve models from macOS (Ollama, MLX) outside the cluster. A Mac
  can't be woken from shutdown, only from sleep (`pmset` schedules or
  "Wake for network access" on power), and a laptop leaves the house. It's
  fine for development, not for the lab's GPU. It does serve models
  manually: woken by hand, it gets a reserved address and the nodes can
  reach Ollama on it ([network](../network.md#firewall-intent)).

## Consequences

- The first request after idle waits for boot and model load, a few minutes.
  The document flow absorbs that; interactive use would not.
- Wake-on-LAN must survive a shutdown from Linux. The BIOS settings are in
  [hardware](../hardware.md#gpu-node) (ErP off, Wake on LAN on), but the
  Realtek NIC's wake setting is also left to the driver at shutdown. To be
  verified before anything depends on it; if Talos leaves it disarmed, it
  needs a fix there or the daily window instead.
- A node that's off is normal, not a failure. Alerting and the failure
  drills ([0006](0006-ai-infrastructure.md)) have to tell the two apart.
- Model weights stay cached on node4's NVMe, or every wake pays for a full
  download from Ceph.
