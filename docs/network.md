# Network

Source of truth for addressing. Router config (`network/routeros/`) and Talos
patches (`talos/`) implement what is written here; change this file first.

## Topology

```
                       internet
                          |
          Virgin Media hub 192.168.0.1   home LAN 192.168.0.0/24
                          |
                   ether1 | DHCP, reserved on the hub
   +----------------------+-----------------------------------+
   | MikroTik hAP ax2                                         |
   |   bridge, vlan-filtering=yes                             |
   |   vlan10 mgmt 10.10.10.1      vlan30 clients 10.10.30.1  |
   |   wg0 10.10.40.1              ether5 rescue 10.10.99.1   |
   |   BGP AS 65000                                           |
   +------+------------+------------+-----------+-------------+
          | ether2     | ether3     | ether4    | Wi-Fi "lab" -> vlan30
          |            |            |
       node1        node2        node3        BGP AS 65001 (Cilium)
   10.10.10.11  10.10.10.12  10.10.10.13      vlan10, untagged
   10.10.20.11  10.10.20.12  10.10.20.13      vlan20, tagged, not routed

   kube API VIP 10.10.10.10 (Talos)
   LoadBalancer pool 10.10.100.0/24, advertised to the hAP over BGP
```

## Subnets

| VLAN | Name | Subnet | Gateway | Lives on | Carries |
|---|---|---|---|---|---|
| 10 | mgmt | 10.10.10.0/24 | 10.10.10.1 | node ports, untagged | Talos API, kube API, etcd, kubelet, node InternalIPs (so pod traffic), BGP sessions |
| 20 | storage | 10.10.20.0/24 | none | node ports, tagged | Ceph cluster network or Longhorn replication. The hAP has no IP here, so nothing can route in or out. |
| 30 | clients | 10.10.30.0/24 | 10.10.30.1 | lab Wi-Fi | Laptop, phone |
| | wireguard | 10.10.40.0/24 | 10.10.40.1 | hAP `wg0` | Access from the home LAN and from outside |
| | rescue | 10.10.99.0/24 | none handed out | hAP ether5, outside the bridge | Break-glass admin port. Set up by `bootstrap.rsc`, never by OpenTofu, so it survives a broken VLAN config or a bad apply |
| | lb-pool | 10.10.100.0/24 | | no interface | Cilium LB-IPAM; routes learned by the hAP over BGP |
| | pods | 10.244.0.0/16 | | | Per-node /24s, Cilium native routing |
| | services | 10.96.0.0/12 | | | ClusterIPs |
| | home | 192.168.0.0/24 | 192.168.0.1 | upstream of ether1 | Virgin hub default; confirm on the hub's admin page |

There is no "services" VLAN on purpose: LoadBalancer IPs are routed prefixes the
hAP learns from the nodes over BGP, so they don't need a network segment.

VLANs on a single 1 GbE port separate traffic logically, not by bandwidth.
Storage replication, pod traffic and etcd share the same link.

## Addresses

Node N is `.1N` in every subnet.

| Address | What |
|---|---|
| 10.10.10.1 | hAP (gateway, DNS, BGP) |
| 10.10.10.10 | Kubernetes API VIP (Talos `vip`) |
| 10.10.10.11-13 | node1-3, static in Talos config |
| 10.10.10.100-199 | DHCP: Talos maintenance mode, new nodes |
| 10.10.20.11-13 | node1-3 storage interfaces, static, no routes |
| 10.10.30.100-254 | DHCP: clients |
| 10.10.40.2+ | WireGuard peers, static per peer |
| 10.10.99.2-9 | DHCP: rescue port |
| 10.10.100.10 | Main Cilium Gateway (all HTTP/gRPC) |
| 10.10.100.20-254 | LB-IPAM pool for other LoadBalancer Services |

`talosctl` talks to node IPs directly, never the VIP: the VIP only exists once
etcd is healthy. In-cluster clients (Cilium included) reach the API through
KubePrism on `localhost:7445`.

## hAP ax2 ports

| Port | Mode | Use |
|---|---|---|
| ether1 | WAN | DHCP client on the Virgin hub, masquerade |
| ether2 | bridge, PVID 10, tagged 20 | node1 |
| ether3 | bridge, PVID 10, tagged 20 | node2 |
| ether4 | bridge, PVID 10, tagged 20 | node3 |
| ether5 | routed, not in bridge | rescue, 10.10.99.1/24 with DHCP (no gateway); configured by `bootstrap.rsc` |
| wifi (2.4 + 5 GHz) | bridge, PVID 30 | SSID `lab` |

VLAN 10 is untagged on node ports so a wiped node in Talos maintenance mode
gets a DHCP lease without any VLAN config.

## Talos node networking

- NIC selected by MAC (`deviceSelector.hardwareAddr`), not by interface name.
- Physical link: `10.10.10.1N/24`, default route via `10.10.10.1`,
  `vip: 10.10.10.10`.
- VLAN 20 sub-interface: `10.10.20.1N/24`, no routes.
- Resolver: `10.10.10.1`. MTU 1500 everywhere to start; jumbo frames on VLAN 20
  are an experiment.

## Kubernetes networking

Starting Cilium settings (final values live in
`kubernetes/infrastructure/cilium/values.yaml`):

- `kubeProxyReplacement: true`, Talos `cluster.proxy.disabled: true`,
  `cluster.network.cni.name: none`
- `k8sServiceHost: localhost`, `k8sServicePort: 7445` (KubePrism)
- `ipam.mode: kubernetes`
- `routingMode: native`, `autoDirectNodeRoutes: true`,
  `ipv4NativeRoutingCIDR: 10.244.0.0/16` (all nodes share one L2 segment,
  so no VXLAN)
- `bgpControlPlane.enabled: true`, `gatewayAPI.enabled: true`, Hubble relay + UI
- Encryption off at first; WireGuard and Istio ambient are compared in
  `experiments/`

## BGP

| | hAP | Cluster |
|---|---|---|
| ASN | 65000 | 65001 |
| Router ID / peers | 10.10.10.1 | 10.10.10.11-13 |
| Advertised | nothing | LB-IPAM addresses as /32s |

The hAP accepts only /32s inside the LB pool from the nodes (`bgp-in-cilium`)
and sends nothing back (`bgp-out-cilium`). The sessions themselves are
switched off until the RouterOS provider supports RouterOS 7.25's BGP
settings; see `network/routeros/README.md`.

To verify while building:

- whether RouterOS installs all three next hops for a /32 (ECMP), with
  `externalTrafficPolicy: Cluster` and with `Local`
- how fast a route is withdrawn when a node dies (graceful restart, timers)

## Firewall intent

| From | To | Allowed |
|---|---|---|
| admin (clients, wireguard, rescue) | mgmt | TCP 6443 (kube API), TCP 50000 (Talos API), ICMP |
| admin | lb-pool | everything |
| admin | hAP | everything (REST API, Winbox and SSH are also limited to these networks) |
| admin | internet | everything |
| mgmt | hAP | DNS, DHCP, TCP 179 (BGP) from the node IPs |
| mgmt | internet | everything (images, Cloudflare API, NTP) |
| home LAN / internet | hAP WAN | UDP WireGuard only |
| anything else | anything | dropped |

The Virgin hub can't hold static routes, so devices on the home LAN reach the
lab through WireGuard (to the hAP's WAN address), not by routing. Remote
access from outside needs a single UDP port forward on the hub to the hAP,
which only works if the hub has a public IPv4 address (no CGNAT).

## DNS and certificates

- Domain: `hamzatest.com`, DNS on Cloudflare.
- App names point at the Gateway: `argocd.hamzatest.com`,
  `hubble.hamzatest.com`, `grafana.hamzatest.com`, ... -> `10.10.100.10`,
  published by external-dns.
- Infrastructure names are static records on the hAP: `router`, `k8s`
  (-> `10.10.10.10`) and `node1`-`node3`, all under `hamzatest.com`. Lab
  clients resolve through the hAP, which forwards everything else to
  Cloudflare (1.1.1.1).
- `k8s.hamzatest.com` goes into the API server cert SANs. The Talos endpoint
  stays the plain IP so the cluster doesn't depend on DNS.
- App names are private IPs in public DNS: no split-horizon setup to maintain.
- Certificates: cert-manager, Let's Encrypt, DNS-01 via a Cloudflare API token
  scoped to this zone; one wildcard `*.hamzatest.com` on the Gateway.
