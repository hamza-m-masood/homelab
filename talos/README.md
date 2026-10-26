# Talos

Machine configs for the three nodes. Nothing in here is a rendered config:
`task talos:gen` builds them into `talos/out/` (gitignored), and CI renders
and validates them on every push with throwaway secrets.

First install: [docs/runbooks/talos-first-boot.md](../docs/runbooks/talos-first-boot.md).
Why Talos and how it's set up: [ADR 0001](../docs/adr/0001-talos-linux.md).

| File | What |
|---|---|
| `talos.env` | Talos and Kubernetes versions, Image Factory schematic ID |
| `schematic.yaml` | System extensions baked into the image (Intel microcode) |
| `secrets.sops.yaml` | Cluster CAs and tokens, SOPS-encrypted. Created once by `task talos:secrets` |
| `patches/common.yaml` | Everything the three nodes share |
| `patches/node-labels.yaml` | Puts the control-plane role label back after `common.yaml` clears the defaults |
| `patches/node1-3.yaml` | Hostname and addresses per node |

## How a config is built

`scripts/talos-gen.sh` does it:

1. `talosctl gen config lab https://10.10.10.10:6443` with the secrets
   bundle, the pinned Kubernetes version and the installer image for the
   schematic, plus `common.yaml` and `node-labels.yaml`.
2. Each `nodeN.yaml` patch on top of that, giving `out/nodeN.yaml`.
3. `talosctl validate --mode metal --strict` on each result.

Talos 1.14 configs are multi-document: networking, the VIP, kubelet and the
install disk each have their own document `kind`. Only etcd is still in the
classic `v1alpha1` document.

## What the patches do, and why

- **One NIC, named by driver.** Each M910q has a single Intel I219-LM. A
  `LinkAliasConfig` names it `lan` by its driver (`e1000e`), so no config
  file holds a MAC address.
- **mgmt only, for anything cluster-internal.** etcd advertises and kubelet
  registers addresses in `10.10.10.0/24`, never the storage VLAN.
- **Storage VLAN.** VLAN 20 is tagged on `lan`, with no gateway: the hAP
  doesn't route it.
- **Workloads on control planes.** The control-plane taint is removed. So are
  Talos's default labels, because one of them
  (`node.kubernetes.io/exclude-from-external-load-balancers`) would stop
  Cilium announcing LoadBalancer IPs from these nodes. `node-labels.yaml`
  adds the role label back.
- **No CNI, no kube-proxy.** Flannel and kube-proxy are off; Cilium replaces
  both in phase 3. Until then nodes are `NotReady` and CoreDNS is `Pending`.
- **Install disk.** The NVMe under 300 GB, so a bigger data disk added to
  the second M.2 slot is never picked.
- **EPHEMERAL capped at 100 GiB.** Talos would otherwise take the rest of
  the boot disk for `/var`. Roughly 135 GiB stays free for the storage
  phase. A volume can grow later but not shrink, so this is set before the
  first install.

## Changing a node

```sh
# edit talos/patches/...
task talos:gen
task talos:apply NODE=node1   # one node at a time; Talos reboots it if the change needs it
```

## Upgrading

Talos: bump `TALOS_VERSION` in `talos.env` and `talosctl` in `.mise.toml`,
then:

```sh
mise install
task talos:gen
task talos:upgrade NODE=node1   # wait for it to rejoin (talosctl -n 10.10.10.11 etcd members), then node2, node3
```

Kubernetes: bump `KUBERNETES_VERSION`, then `task talos:gen` and
`task talos:upgrade-k8s`.

A new extension means a new schematic: edit `schematic.yaml`, run
`task talos:schematic`, put the printed ID in `talos.env`, and upgrade each
node as above.
