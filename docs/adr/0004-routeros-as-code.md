# 0004: RouterOS config as code with OpenTofu

Status: accepted

## Context

The hAP ax2 carries VLANs, DHCP, DNS, firewall, BGP, WireGuard and Wi-Fi.
It has to be reproducible from the repo like everything else, and changes
should be reviewable before they hit the router.

## Decision

- OpenTofu with the `terraform-routeros/routeros` provider, talking to the
  RouterOS REST API (`network/routeros/`).
- State is encrypted with OpenTofu's built-in state encryption and committed.
  The passphrase lives in the SOPS-encrypted secrets file.
- A sanitized `/export` snapshot is committed next to the config, so the
  real device state can be diffed against what OpenTofu thinks it set.
- First boot (factory reset, enable `www-ssl`, create the OpenTofu user) is
  a short manual runbook, the only hand-applied router config.
- Changes made by hand go through Safe Mode. ether5 stays outside the bridge
  as the rescue port, and MAC-Winbox is the last resort.

## Alternatives

- **`.rsc` scripts applied with `/import`**: native, but no plan/diff,
  no drift detection, and re-running them isn't idempotent.
- **Ansible `community.routeros`**: works, but procedural; the declarative
  plan is the point here.
- **Plain Terraform**: same provider, but no built-in state encryption,
  so state couldn't live in a public repo.

## Consequences

- The router has to be reachable over HTTPS from wherever `tofu apply` runs
  (rescue port, lab Wi-Fi or WireGuard).
- Provider coverage lags RouterOS features at times; gaps get a small
  `.rsc` fallback, written down rather than applied silently.
