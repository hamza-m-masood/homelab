# 0002: Network design: hAP as switch, VLANs on one NIC, BGP for LoadBalancers

Status: accepted (revisit after the hardware inventory and the hAP throughput test)

## Context

- Each node most likely has a single 1 GbE port.
- The MikroTik hAP ax2 has four 1 GbE LAN ports, so it can take all three
  nodes directly with one port to spare.
- The only other switch is a Netgear FS116: unmanaged and 10/100 Mbps,
  too slow for any cluster traffic.
- The hAP sits behind a Virgin Media hub that can't hold static routes.
- Goals include networking below L7: VLANs, BGP, eBPF, Gateway API.

## Decision

- Nodes plug straight into hAP ether2-4. The FS116 is not used.
- One bridge with VLAN filtering on the hAP. On node ports VLAN 10 (mgmt) is
  untagged and VLAN 20 (storage) is tagged. VLAN 20 has no gateway and is
  never routed.
- Cilium replaces kube-proxy, uses native routing (nodes share one L2
  segment), and advertises LoadBalancer IPs to the hAP over eBGP
  (AS 65001 to AS 65000). The LB pool is not on any VLAN.
- Gateway API through Cilium's implementation; Hubble for flow visibility.
- ether5 is a rescue port outside the bridge, so a broken VLAN config can't
  lock out the router.
- Access from the home LAN and from outside is WireGuard on the hAP;
  locally there is also a lab Wi-Fi network on VLAN 30.

Full addressing is in [network.md](../network.md).

## Alternatives

- **Cilium L2 announcements / MetalLB L2**: simpler, but ARP-based failover
  teaches nothing about routing and can't do ECMP.
- **Flat network, no VLANs**: works, but loses the storage isolation and the
  VLAN practice.
- **Dedicated storage NIC**: better (separate bandwidth), but depends on the
  hardware supporting a second port.
- **Hub in modem mode, hAP as the home router**: makes lab experiments a
  risk to the house internet.

## Consequences

- VLANs don't divide bandwidth: replication, pod traffic and etcd share one
  1 GbE link. A node-loss rebalance will saturate it and push etcd latency
  up. This gets measured, not avoided.
- Bridge VLAN filtering must be hardware-offloaded on the hAP (`H` flag in
  `/interface/bridge/port print`), or all node-to-node traffic crosses the
  router CPU. First thing to test, with iperf3 before and after enabling it.
- Lab egress is double-NATed. Fine for a lab.
- If the hAP turns out to be a bottleneck, or the hardware allows a second
  NIC, the next purchase is a managed switch. A MikroTik CRS3xx keeps the
  whole network in RouterOS and the same OpenTofu provider.
