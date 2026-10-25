# Router first boot

Takes a hAP ax2 from any state to fully managed by OpenTofu. Also the
recovery procedure: if the router is ever in an unknown state, start again
from step 5.

About 30 minutes the first time. Steps 1-4 happen once per laptop.

## On the laptop

**1. Tools.** Install [mise](https://mise.jdx.dev), then in the repo root:

```sh
mise install   # tofu, sops, age, task, shellcheck at the pinned versions
```

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

**10. Move the laptop cable to ether5**, the rescue port. The laptop gets
10.10.99.2-9 with no gateway, so keep home Wi-Fi on for internet.

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
  start again from step 5.

After re-bootstrapping a router that was already managed:

- Repeat step 11; the CA is new.
- Delete `network/routeros/terraform.tfstate*` before planning. The old state
  describes a router that no longer exists, and RouterOS reuses internal IDs
  after a reset, so stale state can point at the wrong objects.
- The WireGuard key is regenerated: `task router:output` prints the new
  public key for client configs.
