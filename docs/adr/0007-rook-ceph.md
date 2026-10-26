# 0007: Rook-Ceph for storage

Status: accepted

## Context

The storage phase needs replicated block storage for stateful apps and an
S3 endpoint for model weights and checkpoints ([0006](0006-ai-infrastructure.md)).

Per node: 20 GB of RAM after the upgrade, and about 135 GiB free on the
256 GB boot NVMe, because Talos's `EPHEMERAL` volume is capped at 100 GiB
([0001](0001-talos-linux.md)). The NVMe drives are consumer parts without
power-loss protection. Replication runs over the storage VLAN at 1 GbE.

## Decision

- Rook-Ceph with one OSD per node on the free space of the boot disk, three
  replicas, so one node can be lost without losing writes.
- RBD for block volumes, and an RGW object store for the S3 endpoint.
  CephFS only if a workload needs shared files.
- Replication traffic on the storage VLAN, clients on mgmt
  ([network](../network.md)).
- OSD memory lowered from the 4 GB default to about 2 GB so everything fits
  in 20 GB.
- Rook and the Ceph cluster are managed by Argo CD like everything else.

## Alternatives

- **Longhorn**: lighter and simpler for block volumes. No object storage,
  and much less common in AI and HPC clusters.
- **Longhorn plus a separate S3 server**: two storage systems to run and
  learn instead of one.
- **Local volumes only**: nothing replicates, so node loss is data loss and
  there's nothing to learn about storage under failure.

## Consequences

- Ceph is the heaviest component in the cluster: roughly 3-4 GB per node
  even tuned down.
- Without power-loss protection, Ceph's synchronous writes are slow on these
  drives. Expect write numbers well below the disks' rating, and measure it.
- 1 GbE caps replicated writes at roughly 100 MB/s.
- Each OSD needs a raw partition on the boot disk, created through Talos's
  volume config in the storage phase. If the boot disks are too small or too
  slow, OSDs move to a data SSD in the second M.2 slot
  ([hardware](../hardware.md#upgrades)).
