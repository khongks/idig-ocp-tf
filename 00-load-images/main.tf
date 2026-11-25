##############################################################################
# 00-load-images – main.tf
#
# Uploads the IDIG product images to a target registry, following
# https://www.ibm.com/docs/en/dp-interact-gateway/12.1.1?topic=openshift-obtaining-product-files
#
# Steps:
#   1. Load the IBM image-tool archive (idig-image-tool-<version>.tar.gz) and
#      run `<image-tool> upload <registry>`, which pushes every product image.
#   2. (Optional, v12.1.1.2 + Analytics only) copy the LA iFix images from the
#      ifix archive into the registry with skopeo. Not needed on v12.1.1.3+.
#
# Works with podman or docker (container_cli = "auto" prefers podman).
#
# NOTE: This module is standalone and is NOT wired into the root main.tf.
#           cd 00-load-images
#           tofu init && tofu apply
#       Re-run the upload with the same inputs:
#           tofu apply -replace=null_resource.upload_images
#
# Prerequisites on the machine running this module:
#   • podman (machine started on macOS) or docker
#   • skopeo v1.2.2+ – only when install_ifix = true
##############################################################################

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.0"
    }
  }
}

locals {
  scripts_dir = "${abspath(path.module)}/scripts"
  # Scratch area for temporary auth files / ifix extraction. Kept under the
  # module (i.e. under $HOME) so it is visible inside the podman machine /
  # Docker Desktop VM on macOS. Git-ignored; cleaned up by the scripts.
  work_dir = "${abspath(path.module)}/.work"
}

# ---------------------------------------------------------------------------
# Step 1 – Load the image tool and upload all product images
# ---------------------------------------------------------------------------
resource "null_resource" "upload_images" {
  triggers = {
    image_tar_path    = var.image_tar_path
    image_tool_ref    = var.image_tool_ref
    docker_registry   = var.docker_registry
    docker_user       = var.docker_user
    upload_extra_args = join(" ", var.upload_extra_args)
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "bash '${local.scripts_dir}/upload-images.sh'"
    environment = {
      CONTAINER_CLI_PREF = var.container_cli
      IMAGE_TAR_PATH     = var.image_tar_path
      IMAGE_TOOL_REF     = var.image_tool_ref
      TOOL_PLATFORM      = var.image_tool_platform
      REGISTRY           = var.docker_registry
      REG_USER           = var.docker_user
      REG_PASSWORD       = var.docker_password
      UPLOAD_EXTRA_ARGS  = join(" ", var.upload_extra_args)
      WORK_DIR           = local.work_dir
    }
  }

  lifecycle {
    precondition {
      condition     = var.image_tar_path != "" || var.image_tool_ref != ""
      error_message = "Set image_tar_path (to load the image tool) or image_tool_ref (to use an already-loaded one)."
    }
  }
}

# ---------------------------------------------------------------------------
# Step 2 – (Optional) LA iFix images via skopeo
# ---------------------------------------------------------------------------
resource "null_resource" "copy_ifix" {
  count = var.install_ifix ? 1 : 0

  triggers = {
    ifix_archive_path = var.ifix_archive_path
    ifix_images       = jsonencode(var.ifix_images)
    docker_registry   = var.docker_registry
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "bash '${local.scripts_dir}/copy-ifix.sh'"
    environment = {
      IFIX_ARCHIVE_PATH = var.ifix_archive_path
      IFIX_IMAGES       = join("\n", [for i in var.ifix_images : "${i.source_dir}|${i.dest}"])
      REGISTRY          = var.docker_registry
      REG_USER          = var.docker_user
      REG_PASSWORD      = var.docker_password
      DEST_TLS_VERIFY   = tostring(var.registry_tls_verify)
      WORK_DIR          = local.work_dir
    }
  }

  depends_on = [null_resource.upload_images]

  lifecycle {
    precondition {
      condition     = var.ifix_archive_path != "" && length(var.ifix_images) > 0
      error_message = "install_ifix = true requires ifix_archive_path and ifix_images."
    }
  }
}
