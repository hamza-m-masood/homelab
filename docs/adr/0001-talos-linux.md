# 0001: Talos Linux on all three nodes

Status: accepted

## Context

Three bare-metal mini PCs, no existing OS. The lab has to be rebuilt from
Git in about 20 minutes, which rules out hand-configured hosts. Kubernetes
itself is well-trodden ground; the point is the layers underneath it.

## Decision

- Talos Linux on all three nodes. All three are control-plane nodes with
  `cluster.allowSchedulingOnControlPlanes: true`.
- The Kubernetes API endpoint is the Talos VIP `10.10.10.10` (see
  [network](../network.md)). `talosctl` endpoints are the node IPs, because
  the VIP only exists once etcd is healthy. In-cluster clients use KubePrism.
- Config is `talosctl gen config` plus patches in `talos/patches/`. The
  secrets bundle from `talosctl gen secrets` is committed SOPS-encrypted
  ([0005](0005-secrets-sops-age.md)); rendered machine configs are never
  committed.
- The image comes from Talos Image Factory, with the schematic (extensions)
  committed and its ID pinned.

## Alternatives

- **kubeadm or k3s on Debian**: familiar, but SSH and a mutable host invite
  drift, and the rebuild story becomes Ansible.
- **Omni**: manages exactly the parts this lab exists to learn.
- **talhelper**: convenient generator on top of `talosctl`. One more layer;
  revisit if the patch matrix gets unwieldy.

## Consequences

- No SSH. Debugging goes through `talosctl dmesg`, `logs`, `pcap`,
  `dashboard` and the resource API.
- Anything the host needs (microcode, iSCSI tools for Longhorn) has to be a
  system extension baked into the image.
- etcd quorum is 2 of 3: losing one node is survivable, losing two is not.
  Node-loss experiments are deliberately one node at a time.
