# Router first boot

Takes a hAP ax2 from any state to fully managed by OpenTofu. Also the
recovery procedure: if the router is ever in an unknown state, start again
from step 5.

About 30 minutes the first time. Steps 1-4 happen once per laptop.

The admin laptop is the ThinkPad X390 (Linux, NetworkManager), wired in
through a USB Ethernet adapter. Keep its Wi-Fi on the home network for
internet.

## On the laptop

**1. Tools.** Install [mise](https://mise.jdx.dev), then in the repo root:

```sh
mise trust && mise install   # tofu, sops, age, task, shellcheck at the pinned versions
```

If `task` is then "command not found", mise isn't active in your shell:
add `eval "$(mise activate bash)"` to `~/.bashrc` and open a new shell.

You also need `openssl`, `perl` and `scp`, which macOS and Linux already have.

**2. Encryption key.**

```sh
task age:init
```

This creates `~/.config/sops/age/keys.txt` and writes its public key into
`.sops.yaml`. Put a copy of the key file in your password manager; without
it, nothing in the repo can be decrypted. Commit `.sops.yaml`.

**3. Router secrets.**

```sh
task router:secrets
```

This writes `network/routeros/secrets.sops.yaml`, encrypted, containing:

- the admin password
- the OpenTofu API password
- the state passphrase
- the Wi-Fi passphrase

Commit it. To read a value:

```sh
sops decrypt --extract '["TF_VAR_wifi_passphrase"]' network/routeros/secrets.sops.yaml
```

**4. Bootstrap script and provider.**

```sh
task router:bootstrap   # writes network/routeros/out/bootstrap.rsc (gitignored)
task router:init        # downloads the provider; needs internet
```

## On the router

Steps 5-9 get the bootstrap script onto the router through its web page.
For a second-hand router you can't log into, use
[Netinstall](#or-netinstall-for-a-router-you-cant-log-into) instead. It
replaces steps 5-9; this lab's hAP needed it.

**5. Cable it up.**
- Virgin hub (any LAN port) → hAP **ether1**.
- Laptop → hAP **ether2**.

A factory-fresh hAP hands out 192.168.88.x.

**6. Log in.** Browse to http://192.168.88.1 and sign in as `admin` with
the password printed on the sticker underneath.

**7. Update RouterOS.** The config needs RouterOS 7.20 or newer; it was
tested on 7.25.
- Go to System → Packages → Check For Updates, pick channel `stable`, then
  Download & Install. It reboots.
- Then go to System → RouterBOARD → Upgrade and reboot once more, so the
  firmware matches.

**8. Upload the bootstrap script.** Go to Files and drag in
`network/routeros/out/bootstrap.rsc`.

**9. Reset and bootstrap.** Open Terminal (top right in WebFig) and run:

```
/system reset-configuration no-defaults=yes skip-backup=yes run-after-reset=bootstrap.rsc
```

Confirm with `y`. The router wipes itself, reboots and runs the script. That
takes about two minutes, most of it generating certificates.

### Or: Netinstall, for a router you can't log into

Netinstall reinstalls RouterOS from scratch and wipes everything, including
a disabled reset button. With `-sm` it also runs the bootstrap script on the
first boot, so the router comes up exactly as after step 9 and its old
passwords never matter. Needs RouterOS and Netinstall 7.22 or newer.

**N1. Download**, while you still have internet:

```sh
mkdir -p ~/netinstall && cd ~/netinstall
curl -fLO https://download.mikrotik.com/routeros/7.25/netinstall-7.25.tar.gz
curl -fLO https://download.mikrotik.com/routeros/7.25/routeros-7.25-arm64.npk
curl -fLO https://download.mikrotik.com/routeros/7.25/all_packages-arm64-7.25.zip
tar -xzf netinstall-7.25.tar.gz
bsdtar -xf all_packages-arm64-7.25.zip wifi-qcom-7.25-arm64.npk   # Wi-Fi driver
```

**N2. Cable.** Laptop straight into hAP **ether1**, nothing in between.
Unplug the Virgin cable for now.

**N3. Give the laptop's wired port a fixed address**, outside
NetworkManager's control:

```sh
IFACE=enp0s20f0u4   # your wired interface, from `ip -br link`
sudo nmcli device set $IFACE managed no
sudo ip addr flush dev $IFACE
sudo ip addr add 192.168.88.2/24 dev $IFACE
sudo ip link set $IFACE up
sudo ufw disable    # if a firewall is active; it blocks the router's boot request
```

**N4. Start Netinstall.** It waits for the router:

```sh
sudo ./netinstall-cli -e -sm ~/path/to/homelab/network/routeros/out/bootstrap.rsc \
  -i $IFACE -a 192.168.88.3 routeros-7.25-arm64.npk wifi-qcom-7.25-arm64.npk
```

`-e` installs with an empty config (no MikroTik defaults); `-sm` runs the
bootstrap script once on first boot.

**N5. Put the router into Netinstall mode.** Power off, hold the reset
button, power on, and keep holding for about 20 seconds. The USR LED
flashes, then goes solid, then turns off: release when it turns off.
Netinstall prints "Successfully finished installing device" and the router
reboots.

**N6. Hand the port back and re-cable:**

```sh
sudo ip addr flush dev $IFACE
sudo nmcli device set $IFACE managed yes
sudo ufw enable
```

Laptop → hAP **ether5**, Virgin → hAP **ether1**. Give the router about
3 minutes to run the script, then `nmcli device connect $IFACE` until
`ip -br addr` shows a 10.10.99.x address. Continue at step 10.

If Netinstall sits at "Waiting for RouterBOARD":

- `ip -br addr show $IFACE` must say UP; if not, `sudo ip link set $IFACE up`.
- The firewall must be off (`sudo ufw status`).
- The cable must be in ether1.
- Hold the button longer: releasing at the first flashes only resets the
  config.

**10. Move the laptop cable to ether5**, the rescue port. This is the
X390's permanent wired port. The laptop gets:

- an address in 10.10.99.2-9
- the router (10.10.99.1) as DNS
- a route to the whole lab (10.10.0.0/16)

It gets no default gateway, so internet stays on home Wi-Fi.
`ip route get 10.10.10.1` should show `via 10.10.99.1`.

Then delete the rendered script, which contains passwords:

```sh
rm network/routeros/out/bootstrap.rsc
```

**11. Pin the router's CA.** The admin password is
`ROUTEROS_ADMIN_PASSWORD` in the secrets file.

```sh
scp admin@10.10.99.1:router-ca.crt network/routeros/   # add -O if scp complains
```

Commit `router-ca.crt`. It's a public certificate, and every apply checks
the router against it.

Check the script didn't leave a copy behind (it holds the passwords):
`ssh admin@10.10.99.1 /file print`, and `/file remove <name>` if it did.

**12. Apply.**

```sh
task router:plan    # about 70 resources to add
task router:apply
```

## Check it worked

- `task router:plan` again shows "No changes".
- A phone or laptop can join SSID `lab`, gets a 10.10.30.x address, and has
  internet.
- In Winbox or WebFig, IP → Firewall shows the input and forward chains each
  ending in a drop.

Commit `network/routeros/terraform.tfstate`. It's encrypted.

## When something goes wrong

- **The apply fails halfway.** Fix the cause and plan/apply again. The
  rescue port isn't managed by OpenTofu, so it keeps working.
- **10.10.99.1 doesn't answer after step 9.** The script probably stopped
  on an error. Connect with Winbox using the router's MAC address (Neighbors
  tab; it works without IP config), and look at Log for the failing line.
- **Locked out completely.** Hold the reset button while powering on until
  the LED flashes, then release. The router is back on factory defaults:
  start again from step 5. If the router keeps its old settings after that,
  its reset button has been disabled: use Netinstall.

After re-bootstrapping a router that was already managed:

- Repeat step 11; the CA is new.
- Delete `network/routeros/terraform.tfstate*` before planning. The old state
  describes a router that no longer exists, and RouterOS reuses internal IDs
  after a reset, so stale state can point at the wrong objects.
- The WireGuard key is regenerated: `task router:output` prints the new
  public key for client configs.
