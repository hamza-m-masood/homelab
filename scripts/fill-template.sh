#!/usr/bin/env bash
# Replace ${VAR} placeholders in a template with values from the environment.
# Only the variables named on the command line are replaced, and each must be
# set, so a typo fails loudly instead of rendering an empty password.
#
#   fill-template.sh network/routeros/bootstrap.rsc VAR1 VAR2 > out.rsc
set -euo pipefail

template=$1
shift

content=$(<"$template")
for var in "$@"; do
  value=${!var-}
  if [[ -z $value ]]; then
    echo "$var is not set" >&2
    exit 1
  fi
  content=${content//"\${$var}"/"$value"}
done

printf '%s\n' "$content"
