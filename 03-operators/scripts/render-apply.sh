#!/usr/bin/env bash
# Render a release-file manifest with the IBM placeholder substitutions and
# apply it. Mirrors the `sed -i` steps in the IDIG install docs, but writes to
# RENDER_DIR so the release bundle is never modified.
#
#   render-apply.sh <source.yaml> [extra `oc apply` args...]
#
# Environment:
#   KUBECONFIG, NAMESPACE, REGISTRY, PULL_SECRET – required
#   STORAGE_CLASS – value for REPLACE-STORAGE-CLASS; empty removes the
#                   storageClassName line so the cluster default is used
#   RENDER_DIR    – where rendered files are written (kept for inspection)
set -euo pipefail

SRC="$1"; shift
: "${NAMESPACE:?}" "${REGISTRY:?}" "${PULL_SECRET:?}" "${RENDER_DIR:?}"

if [[ ! -f "$SRC" ]]; then
  echo "ERROR: $SRC not found. Check release_files_path." >&2
  exit 1
fi

mkdir -p "$RENDER_DIR"
OUT="$RENDER_DIR/$(basename "$SRC")"

SED=(
  -e "s|REPLACE-NAMESPACE|${NAMESPACE}|g"
  -e "s|REPLACE-DOCKER-REGISTRY|${REGISTRY}|g"
  -e "s|DEFAULT_IMAGE_PULL_SECRET|${PULL_SECRET}|g"
)
if [[ -n "${STORAGE_CLASS:-}" ]]; then
  SED+=(-e "s|REPLACE-STORAGE-CLASS|${STORAGE_CLASS}|g")
else
  SED+=(-e "/storageClassName: *REPLACE-STORAGE-CLASS/d")
fi
sed "${SED[@]}" "$SRC" > "$OUT"

if grep -nE 'REPLACE[-_][A-Z]|DEFAULT_IMAGE_PULL_SECRET' "$OUT"; then
  echo "ERROR: unreplaced placeholders remain in $OUT" >&2
  exit 1
fi

echo "==> oc apply $(basename "$SRC") $*"
oc apply -n "$NAMESPACE" -f "$OUT" "$@"
