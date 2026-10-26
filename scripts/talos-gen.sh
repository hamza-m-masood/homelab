#!/usr/bin/env bash
# Render and validate the three node configs from talos/patches.
#
#   talos-gen.sh <secrets.yaml> <output dir>
#
# Writes node1-3.yaml and talosconfig to the output directory. Versions and
# the Image Factory schematic come from talos/talos.env. Cluster name and
# endpoint (the API VIP) are from docs/network.md.
set -euo pipefail

secrets=$1
out=$2
root=$(cd "$(dirname "$0")/.." && pwd)

# shellcheck disable=SC1091 # path is computed at runtime
source "$root/talos/talos.env"

# The config schema follows the talosctl version, so render with the pinned one.
if ! talosctl version --client --short | grep -qx "Talos $TALOS_VERSION"; then
  echo "talosctl is not $TALOS_VERSION (see .mise.toml): $(talosctl version --client --short | tail -1)" >&2
  exit 1
fi

mkdir -p "$out"
talosctl gen config lab https://10.10.10.10:6443 \
  --with-secrets "$secrets" \
  --kubernetes-version "$KUBERNETES_VERSION" \
  --install-image "factory.talos.dev/metal-installer/$TALOS_SCHEMATIC:$TALOS_VERSION" \
  --config-patch "@$root/talos/patches/common.yaml" \
  --config-patch "@$root/talos/patches/node-labels.yaml" \
  --output-types controlplane,talosconfig \
  --with-docs=false --with-examples=false \
  --output "$out" --force

for n in 1 2 3; do
  talosctl machineconfig patch "$out/controlplane.yaml" \
    --patch "@$root/talos/patches/node$n.yaml" --output "$out/node$n.yaml"
  talosctl validate --config "$out/node$n.yaml" --mode metal --strict
done
rm "$out/controlplane.yaml" # only the per-node files get applied

talosctl --talosconfig "$out/talosconfig" config endpoint 10.10.10.11 10.10.10.12 10.10.10.13
talosctl --talosconfig "$out/talosconfig" config node 10.10.10.11
