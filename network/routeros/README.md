# RouterOS (hAP ax2)

OpenTofu config for the lab router, implementing [docs/network.md](../../docs/network.md).
Decision record: [ADR 0004](../../docs/adr/0004-routeros-as-code.md).
First-time setup: [router first boot](../../docs/runbooks/router-first-boot.md).

## Day to day

```sh
task router:plan    # review
task router:apply   # applies exactly that plan
```

Both run through `sops exec-env`, so the secrets in `secrets.sops.yaml` only ever
exist as environment variables. Commit `terraform.tfstate` after an apply: it is
encrypted.

## What's where

| File | Manages |
|---|---|
| `interfaces.tf` | bridge with VLAN filtering, ports, VLAN interfaces, interface lists |
| `addressing.tf` | WAN DHCP client, gateway addresses, DHCP pools and servers, DNS |
| `firewall.tf` | filter rules (ordered), masquerade |
| `bgp.tf` | BGP instance, route filters, sessions to the nodes |
| `wireguard.tf` | `wg0` and its peers |
| `wifi.tf` | both radios, SSID `lab` |
| `system.tf` | identity, NTP, management services, MAC-Winbox, neighbour discovery |
| `locals.tf` | addressing, mirrored from docs/network.md |

Not managed here, on purpose: everything `bootstrap.rsc` sets up (rescue port on
ether5, the `admin` and `tofu` users, the HTTPS certificates). A bad apply
can't remove the way back in.

## Known gaps

- **BGP sessions are switched off** (`bgp_connections_enabled` in `bgp.tf`).
  Provider 1.99.1 always sends `add-path-out` on a connection, and RouterOS 7.25
  rejects it (the setting is now `output.add-path`). The instance and filters
  are applied. The sessions only matter once Cilium runs BGP, by which point the
  provider may be fixed. If not, fixing it upstream is a small Go change.

- **"Field '…' not found in the schema" warnings.** The same provider lag:
  RouterOS 7.25 reports fields provider 1.99.1 doesn't know (for example
  `mlag_init_delay` on the bridge). They are ignored and don't affect plans.
  The `task` targets pass `-compact-warnings` so they take one line each.

## How this was tested

On the real hAP ax2 (RouterOS 7.25, bootstrapped with Netinstall): a full
apply, a second plan with no changes, and a phone on SSID `lab` that gets a
10.10.30.x address, DNS and internet.

Before that, against RouterOS CHR 7.25 (MikroTik's x86 build) in QEMU, with five NICs
standing in for ether1-5: factory reset with `run-after-reset=bootstrap.rsc`,
then `plan`/`apply` through the same tasks, against `https://10.10.99.1`
with the pinned CA. Results:

- a full apply from scratch succeeds, and a second plan shows no changes
- the state file holds no plaintext
- the firewall comes out in the intended order
- with ether5 on a TAP device, a real DHCP client (busybox `udhcpc`) gets
  DNS 10.10.99.1 and the 10.10.0.0/16 route, with no default gateway. Lab
  names resolve and the router's mgmt, clients and WireGuard addresses
  answer through that route

Bugs this caught, now fixed:

- The final drop rules could be created before the accepts, cutting OpenTofu
  off mid-apply. They are now created last.
- `hw-offload` on the fasttrack rule doesn't exist on this RouterOS.
- DHCP servers showed a diff on every plan until `dynamic_lease_identifiers`
  was set explicitly.
