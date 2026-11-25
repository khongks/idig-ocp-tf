#!/usr/bin/env bash
# Loads the IBM idig-image-tool image and runs its `upload` command, which
# pushes all IDIG product images to the target registry.
#
# Follows: https://www.ibm.com/docs/en/dp-interact-gateway/12.1.1?topic=openshift-obtaining-product-files
#   docker load < idig-image-tool-<version>.tar.gz
#   docker run --rm idig-image-tool-<version> version --images
#   docker run --rm -v ~/.docker:/root/.docker --user 0 idig-image-tool-<version> upload $APIC_DOCKER_REGISTRY
#
# Environment (set by Terraform):
#   CONTAINER_CLI_PREF   auto | podman | docker
#   IMAGE_TAR_PATH       path to idig-image-tool tar.gz (ignored if IMAGE_TOOL_REF set)
#   IMAGE_TOOL_REF       already-loaded image-tool reference; skips the load
#   TOOL_PLATFORM        e.g. linux/amd64 ("" to omit --platform)
#   REGISTRY             target registry path (host[/namespace])
#   REG_USER, REG_PASSWORD
#   UPLOAD_EXTRA_ARGS    extra args appended to `upload` (space separated)
#   WORK_DIR             scratch dir for the temporary auth file
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

CLI="$(select_cli "${CONTAINER_CLI_PREF:-auto}")"
echo "==> Using container CLI: $CLI ($("$CLI" --version))"

# --- Load the image tool -----------------------------------------------------
TOOL_REF="${IMAGE_TOOL_REF:-}"
if [[ -z "$TOOL_REF" ]]; then
  if [[ ! -f "$IMAGE_TAR_PATH" ]]; then
    echo "ERROR: image_tar_path '$IMAGE_TAR_PATH' does not exist or is not a file." >&2
    exit 1
  fi
  echo "==> Loading $IMAGE_TAR_PATH (this can take several minutes) ..."
  LOAD_OUT="$("$CLI" load -i "$IMAGE_TAR_PATH")"
  echo "$LOAD_OUT"
  # docker:  "Loaded image: idig-image-tool-12.1.1:latest"  (or "Loaded image ID: sha256:...")
  # podman:  "Loaded image: docker.io/library/idig-image-tool-12.1.1:latest"
  #          older podman: "Loaded image(s): ref1,ref2"
  TOOL_REF="$(printf '%s\n' "$LOAD_OUT" | sed -nE 's/^Loaded image[^:]*: *//p' | tail -n1 | cut -d, -f1)"
  if [[ -z "$TOOL_REF" ]]; then
    echo "ERROR: could not determine the loaded image reference from '$CLI load' output." >&2
    exit 1
  fi
fi
echo "==> Image tool: $TOOL_REF"

RUN_OPTS=(--rm)
[[ -n "${TOOL_PLATFORM:-}" ]] && RUN_OPTS+=(--platform "$TOOL_PLATFORM")

# --- List the images that will be uploaded -----------------------------------
echo "==> Images included in the image tool:"
"$CLI" run "${RUN_OPTS[@]}" "$TOOL_REF" version --images

# --- Credentials for the target registry ------------------------------------
AUTH_DIR="$(write_auth_dir "$WORK_DIR" "$REGISTRY" "$REG_USER" "$REG_PASSWORD")"
trap 'rm -rf "$AUTH_DIR"' EXIT

MOUNT="$AUTH_DIR:/root/.docker"
# SELinux relabel only matters on Linux hosts; on macOS (podman machine /
# Docker Desktop / Rancher Desktop) it can fail on the shared filesystem.
if [[ "$CLI" == podman && "$(uname -s)" == Linux ]]; then
  MOUNT+=":Z"
fi

# --- Upload -------------------------------------------------------------------
read -r -a EXTRA <<< "${UPLOAD_EXTRA_ARGS:-}"
echo "==> Uploading images to $REGISTRY ..."
# The image sets HOME=/home, so the /root/.docker mount from the IBM docs is
# not where the tool looks by default. Point it at the file explicitly:
#   REGISTRY_AUTH_FILE – containers/image (what the tool pushes with)
#   DOCKER_CONFIG      – docker-cli-style lookup
"$CLI" run "${RUN_OPTS[@]}" \
  -v "$MOUNT" \
  -e REGISTRY_AUTH_FILE=/root/.docker/config.json \
  -e DOCKER_CONFIG=/root/.docker \
  --user 0 \
  "$TOOL_REF" upload "$REGISTRY" ${EXTRA[@]+"${EXTRA[@]}"}

echo "==> Upload complete."
