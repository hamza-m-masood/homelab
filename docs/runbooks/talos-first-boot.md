# Talos first boot

Takes the three M910qs from wiped (or any OS) to a three-node Kubernetes
control plane. Nodes stay `NotReady` until Cilium goes in (phase 3); that's
expected.

About 45 minutes the first time. Also the recovery procedure for a single
node: reinstall it from step 5.

You need:

- the router done ([router first boot](router-first-boot.md)) and the X390
  wired into hAP ether5
- node1, node2, node3 labelled and cabled to hAP ether2, ether3, ether4
  ([hardware](../hardware.md))
- a monitor and USB keyboard, moved from node to node
- one USB stick (1 GB is plenty; it gets overwritten)

## On the laptop

**1. Tools.** In the repo root:

```sh
mise install   # adds talosctl and kubectl
```

mise also sets `TALOSCONFIG` and `KUBECONFIG` to files in `talos/out/` while
you're in the repo, so plain `talosctl` and `kubectl` talk to the lab.

**2. Cluster secrets.**

```sh
task talos:secrets
```

This writes `talos/secrets.sops.yaml`, encrypted: the cluster's CAs, etcd
keys and join tokens. Commit it. It is made once per cluster; a new one means
a new cluster, every node reinstalled.

**3. Configs.**

```sh
task talos:gen
```

This writes `talos/out/node1.yaml`, `node2.yaml`, `node3.yaml` and
`talosconfig`. They hold the secrets in plain text: they're gitignored, and
never paste them anywhere. Re-run it whenever a patch changes, or after a
year, when the `talosconfig` client certificate expires.

**4. USB stick.**

```sh
task talos:iso    # prints the ISO URL for the pinned version and schematic
curl -fLO <that URL>
lsblk             # find the stick, e.g. /dev/sda; check the size
sudo dd if=metal-amd64.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

`dd` overwrites whatever `of=` points at. Double-check it's the stick, not
the laptop's NVMe.

## Each node: node1, then node2, then node3

**5. BIOS.** Monitor and keyboard on the node, power on, F1. Set what's in
the [BIOS table](../hardware.md#bios-settings-for-the-minis-f1-at-power-on); the AMT and
BIOS update can wait. Save and power off.

**6. Boot the stick.** Insert it, power on, F12, choose the USB stick. Talos
starts in maintenance mode: the screen shows a dashboard with the node's
address from DHCP, something in `10.10.10.100-199`.

Talos runs from RAM, so once the dashboard is up, take the stick out. The
node then comes back from its NVMe after installing, and the stick is free
for the next node.

Optional check that it sees the right disk and NIC (`--insecure` because the
node has no config yet):

```sh
talosctl get disks --insecure --nodes 10.10.10.1xx   # nvme0n1, ~256 GB
talosctl get links --insecure --nodes 10.10.10.1xx -o yaml | grep driver:   # e1000e
```

**7. Install.**

```sh
task talos:install NODE=node1 IP=10.10.10.1xx
```

The node downloads the installer image from Image Factory, wipes the NVMe,
installs and reboots. That's a few minutes. It comes back on its static
address and stays there:

```sh
talosctl --nodes 10.10.10.11 version         # client and server both v1.14.5
talosctl --nodes 10.10.10.11 service etcd    # Preparing until step 8; that's fine
```

Repeat 5-7 for node2 (`10.10.10.12`) and node3 (`10.10.10.13`).

## Once all three are installed

**8. Bootstrap etcd.**

```sh
task talos:bootstrap
```

Only ever once per cluster, and only on one node. A minute or two later:

```sh
talosctl --nodes 10.10.10.11 etcd members    # three members, node1-3
ping 10.10.10.10                             # the API VIP
```

**9. Kubernetes.**

```sh
task talos:kubeconfig
kubectl get nodes -o wide
```

Expected: node1-3, role `control-plane`, internal IPs `10.10.10.11-13`, all
`NotReady` (no CNI yet). `kubectl get pods -A` shows CoreDNS `Pending` for the
same reason. Check the API answers on its DNS name too:

```sh
curl -sk https://k8s.hamzatest.com:6443/version
```

Next is phase 3: Cilium.

## When something's wrong

- **No DHCP address in maintenance mode.** The node must be on ether2-4,
  where VLAN 10 is untagged. Leases are on the hAP:
  `ssh admin@10.10.99.1 /ip dhcp-server lease print` (the password:
  `sops decrypt --extract '["ROUTEROS_ADMIN_PASSWORD"]' network/routeros/secrets.sops.yaml`).
- **`talos:install` times out.** The X390 has to be on ether5 (the firewall
  lets the admin networks reach port 50000 on mgmt). `ping 10.10.10.1xx`.
- **Install fails pulling the image.** mgmt needs the internet through the
  hAP; the error is on the node's screen.
- **Watch a node.** `talosctl --nodes 10.10.10.11 dashboard`, `dmesg`,
  `logs kubelet`, `logs etcd`.
- **Reinstall one node.** `talosctl --nodes 10.10.10.1N reset --graceful`
  takes it out of etcd and wipes it. Then from step 6.
- **Start the whole cluster again.** Reset all three
  (`--graceful=false` on the last one), then from step 6, then step 8.
