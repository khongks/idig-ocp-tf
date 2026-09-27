##############################################################################
# 00-load-images – main.tf
#
# Loads IDIG container images from a local archive into a target registry.
# Optionally copies an ifix image from a remote registry using skopeo.
#
# Steps:
#   1. Validate inputs and tool availability (docker / podman, skopeo if needed)
#   2. Load images from the tar archive and push to the target registry
#   3. (Optional) Copy the ifix image using skopeo
#
# NOTE: This module is standalone and is NOT wired into the root main.tf.
#       Run it independently:
#           cd 00-load-images
#           tofu init && tofu apply
#
# Prerequisites on the machine running this module:
#   • docker (or podman) – for loading and pushing the image archive
#   • skopeo              – only when install_ifix = true
##############################################################################

terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Step 1 – Validate inputs and required tool availability
# ---------------------------------------------------------------------------
resource "null_resource" "validate" {
  triggers = {
    image_tar_path    = var.image_tar_path
    docker_registry   = var.docker_registry
    install_ifix      = tostring(var.install_ifix)
    ifix_source_image = var.ifix_source_image
    ifix_dest_image   = var.ifix_dest_image
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail

      # --- Validate archive path ---
      if [[ ! -f "${var.image_tar_path}" ]]; then
        echo "ERROR: image_tar_path '${var.image_tar_path}' does not exist or is not a file."
        exit 1
      fi

      # --- Determine container CLI (prefer podman, fall back to docker) ---
      if command -v podman &>/dev/null; then
        CONTAINER_CLI=podman
      elif command -v docker &>/dev/null; then
        CONTAINER_CLI=docker
      else
        echo "ERROR: Neither 'podman' nor 'docker' found on PATH. Install one before running this step."
        exit 1
      fi
      echo "Using container CLI: $CONTAINER_CLI"

      # --- Validate ifix inputs when enabled ---
      if [[ "${tostring(var.install_ifix)}" == "true" ]]; then
        if ! command -v skopeo &>/dev/null; then
          echo "ERROR: 'skopeo' not found on PATH. Install skopeo before running this step with install_ifix=true."
          exit 1
        fi
        if [[ -z "${var.ifix_source_image}" ]]; then
          echo "ERROR: ifix_source_image must be set when install_ifix = true."
          exit 1
        fi
        if [[ -z "${var.ifix_dest_image}" ]]; then
          echo "ERROR: ifix_dest_image must be set when install_ifix = true."
          exit 1
        fi
        if [[ -z "${var.ifix_source_creds}" ]]; then
          echo "ERROR: ifix_source_creds must be set when install_ifix = true."
          exit 1
        fi
        echo "skopeo found: $(skopeo --version)"
      fi

      echo "Validation passed."
    EOT
  }
}

# ---------------------------------------------------------------------------
# Step 2 – Load image archive and push to the target registry
#
# The archive produced by IBM is a docker-save style .tar/.tgz that may
# contain one or more tagged images. The script:
#   a. Loads the archive with 'docker/podman load'
#   b. Re-tags each loaded image to the target registry
#   c. Pushes all re-tagged images
# ---------------------------------------------------------------------------
resource "null_resource" "load_images" {
  triggers = {
    image_tar_path  = var.image_tar_path
    docker_registry = var.docker_registry
    docker_user     = var.docker_user
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail

      CONTAINER_CLI=docker
      command -v podman &>/dev/null && CONTAINER_CLI=podman

      REGISTRY="${var.docker_registry}"
      TAR="${var.image_tar_path}"

      echo "==> Logging in to $REGISTRY ..."
      echo "${var.docker_password}" | $CONTAINER_CLI login "$REGISTRY" \
        --username "${var.docker_user}" --password-stdin

      echo "==> Loading image archive: $TAR ..."
      LOADED=$($CONTAINER_CLI load --input "$TAR" 2>&1)
      echo "$LOADED"

      # Parse 'Loaded image: <ref>' or 'Loaded image ID: <id>' lines and push each
      echo "$LOADED" | grep -E "^Loaded image" | while read -r line; do
        # Extract the image reference (everything after the last colon-separated label)
        SOURCE_REF=$(echo "$line" | sed 's/^Loaded image[^:]*: //')
        # Derive a target tag: strip any leading hostname and replace with the target registry
        IMAGE_BASENAME=$(echo "$SOURCE_REF" | sed 's|^[^/]*/||')
        TARGET_REF="$REGISTRY/$IMAGE_BASENAME"

        echo "  Re-tagging $SOURCE_REF -> $TARGET_REF"
        $CONTAINER_CLI tag "$SOURCE_REF" "$TARGET_REF"

        echo "  Pushing $TARGET_REF ..."
        $CONTAINER_CLI push "$TARGET_REF"
      done

      echo "==> Image load and push complete."
    EOT
  }

  depends_on = [null_resource.validate]
}

# ---------------------------------------------------------------------------
# Step 3 – (Optional) Copy ifix image via skopeo
#
# Enabled only when var.install_ifix = true.
# Copies the ifix directly from the IBM Container Registry (or any OCI
# registry) into the target registry without a local daemon round-trip.
# ---------------------------------------------------------------------------
resource "null_resource" "copy_ifix" {
  count = var.install_ifix ? 1 : 0

  triggers = {
    ifix_source_image = var.ifix_source_image
    ifix_dest_image   = var.ifix_dest_image
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail

      SOURCE="${var.ifix_source_image}"
      DEST="${var.ifix_dest_image}"
      SRC_CREDS="${var.ifix_source_creds}"
      DEST_CREDS="${var.docker_user}:${var.docker_password}"

      echo "==> Copying ifix image using skopeo ..."
      echo "    Source: $SOURCE"
      echo "    Dest:   $DEST"

      skopeo copy \
        --src-creds  "$SRC_CREDS" \
        --dest-creds "$DEST_CREDS" \
        "docker://$SOURCE" \
        "docker://$DEST"

      echo "==> ifix image copy complete."
    EOT
  }

  depends_on = [null_resource.load_images]
}
