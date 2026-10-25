# 0005: Secrets with SOPS and age

Status: accepted

## Context

The repo is public. Secrets it needs:

- the Talos secrets bundle (cluster CA keys, tokens)
- router credentials, the Wi-Fi passphrase, WireGuard keys
- the OpenTofu state passphrase
- a Cloudflare API token for cert-manager and external-dns

A rebuild must not depend on any of them surviving inside the old cluster.

## Decision

- SOPS with age for every secret, in every layer. Files are named
  `*.sops.yaml` and the rules live in `.sops.yaml`.
- One age key, kept in a password manager. It is the only secret carried by
  hand.
- In-cluster, Argo CD decrypts with KSOPS in the repo-server. The bootstrap
  task creates the age key Secret before Argo CD starts.
- CI runs gitleaks so a plaintext secret fails the build.

## Alternatives

- **Sealed Secrets**: the controller's key is new on every rebuild, so old
  sealed secrets stop decrypting unless the key is backed up somewhere,
  which brings back the same problem.
- **External Secrets with 1Password or Bitwarden**: good, but adds an
  external dependency. Possible later on top of this.
- **Vault or OpenBao in the cluster**: chicken-and-egg for a cluster that
  gets wiped.

## Consequences

- Losing the age key means losing every secret in the repo. It needs a
  second copy offline.
- Rotating the age key means re-encrypting every `*.sops.yaml` (`sops updatekeys`).
