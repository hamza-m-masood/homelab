# 0003: Argo CD for GitOps

Status: accepted

## Context

Everything above the OS should be reconciled from this repo, and a rebuild
should finish with one bootstrap command. GitOps is not on my CV yet.

## Decision

Argo CD, managing itself after a one-time bootstrap:

1. `talosctl bootstrap` brings up etcd and the API server.
2. The bootstrap task installs Cilium once from
   `kubernetes/infrastructure/cilium/values.yaml`. Without a CNI nothing,
   including Argo CD, can schedule.
3. The bootstrap task installs Argo CD and the root Application from
   `kubernetes/bootstrap/`.
4. Argo CD takes over Cilium from the same values file, then syncs
   everything else.

Layout: an ApplicationSet with a git-directory generator creates one
Application per component directory. Sync waves order CRDs, then
controllers, then their custom resources, then workloads.

## Alternatives

**Flux**: native SOPS decryption, real Helm releases, explicit `dependsOn`
and a cleaner `flux bootstrap`. Less common in the enterprises I work with.

## Why Argo CD anyway

- It's what customers run, and OpenShift GitOps is Argo CD.
- Argo CD renders charts with `helm template` (no Helm release, hooks mapped
  to sync phases). A lot of Helm chart escalations come from exactly that,
  so running it daily is direct practice.
- The UI is useful for demos and write-ups.

## Consequences

- No native SOPS: secrets are decrypted by KSOPS in the repo-server
  ([0005](0005-secrets-sops-age.md)).
- Self-management is set up by hand once in `kubernetes/bootstrap/`.
- A "same lab on Flux" comparison stays possible later.
