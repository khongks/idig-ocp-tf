#!/usr/bin/env bash
# Extracts an IDIG ifix archive and copies its images (skopeo `dir:` layout)
# into the target registry.
#
# Only needed for v12.1.1.2 with Analytics enabled (LA iFix AM-3536).
# NOT needed for v12.1.1.3 or later.
#
# Environment (set by Terraform):
#   IFIX_ARCHIVE_PATH    path to e.g. interact-gateway-v12.1.1.2-ifix1.AM-3536.tar.gz
#   IFIX_IMAGES          newline-separated "<dir relative to archive root>|<repo:tag>"
#   REGISTRY             target registry path (host[/namespace])
#   REG_USER, REG_PASSWORD
#   DEST_TLS_VERIFY      true | false
#   WORK_DIR             scratch dir for extraction and the temporary auth file
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

command -v skopeo >/dev/null 2>&1 || { echo "ERROR: skopeo not found on PATH (v1.2.2+ required)." >&2; exit 1; }
echo "==> $(skopeo --version)"

if [[ ! -f "$IFIX_ARCHIVE_PATH" ]]; then
  echo "ERROR: ifix_archive_path '$IFIX_ARCHIVE_PATH' does not exist or is not a file." >&2
  exit 1
fi
if [[ -z "${IFIX_IMAGES//[[:space:]]/}" ]]; then
  echo "ERROR: ifix_images is empty." >&2
  exit 1
fi

mkdir -p "$WORK_DIR"
EXTRACT_DIR="$(mktemp -d "$WORK_DIR/ifix.XXXXXX")"
AUTH_DIR="$(write_auth_dir "$WORK_DIR" "$REGISTRY" "$REG_USER" "$REG_PASSWORD")"
trap 'rm -rf "$AUTH_DIR" "$EXTRACT_DIR"' EXIT

echo "==> Extracting $IFIX_ARCHIVE_PATH ..."
tar xf "$IFIX_ARCHIVE_PATH" -C "$EXTRACT_DIR"

while IFS='|' read -r SRC DEST; do
  [[ -z "${SRC// /}" ]] && continue
  if [[ ! -d "$EXTRACT_DIR/$SRC" ]]; then
    echo "ERROR: '$SRC' not found in the ifix archive." >&2
    exit 1
  fi
  echo "==> skopeo copy dir:$SRC -> docker://$REGISTRY/$DEST"
  skopeo copy \
    --dest-authfile "$AUTH_DIR/config.json" \
    --dest-tls-verify="${DEST_TLS_VERIFY:-true}" \
    "dir:$EXTRACT_DIR/$SRC" \
    "docker://$REGISTRY/$DEST"
done <<< "$IFIX_IMAGES"

echo "==> ifix image copy complete."
echo "    Remember to update the idig-operator image (create-webhook, delete-webhook"
echo "    and manager containers) in ibm-idig-operator.yaml with the ifix tag@digest."
