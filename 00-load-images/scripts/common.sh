#!/usr/bin/env bash
# Shared helpers for 00-load-images. Sourced by the other scripts.

# select_cli <auto|podman|docker>
# Prints the container CLI to use and checks that its engine is reachable
# (for podman on macOS this means `podman machine start` has been run).
select_cli() {
  local pref="${1:-auto}" cli=""
  case "$pref" in
    podman|docker) cli="$pref" ;;
    auto)
      if command -v podman >/dev/null 2>&1; then cli=podman
      elif command -v docker >/dev/null 2>&1; then cli=docker
      fi ;;
    *) echo "ERROR: container_cli must be auto, podman or docker (got '$pref')." >&2; return 1 ;;
  esac
  if [[ -z "$cli" ]] || ! command -v "$cli" >/dev/null 2>&1; then
    echo "ERROR: container CLI '${cli:-podman/docker}' not found on PATH." >&2
    return 1
  fi
  if ! "$cli" info >/dev/null 2>&1; then
    echo "ERROR: '$cli info' failed. Is the engine running? (podman: 'podman machine start'; docker: start Docker/Rancher Desktop)" >&2
    return 1
  fi
  echo "$cli"
}

# write_auth_dir <work_dir> <registry> <user> <password>
# Creates a private directory holding a Docker-format config.json with an
# inline "auth" entry for the registry host, and prints its path.
#
# A self-written file is used instead of `docker login` because:
#   * docker on macOS stores credentials in the keychain (credsStore), so
#     mounting ~/.docker into the image-tool container gives it no creds;
#   * podman keeps creds in ~/.config/containers/auth.json, not ~/.docker.
# The same file works for the image-tool container (mounted at /root/.docker)
# and for skopeo (--dest-authfile).
write_auth_dir() {
  local work_dir="$1" registry="$2" user="$3" password="$4"
  local host="${registry%%/*}"
  mkdir -p "$work_dir"
  local dir
  dir="$(mktemp -d "$work_dir/auth.XXXXXX")"
  chmod 700 "$dir"
  local b64
  b64="$(printf '%s:%s' "$user" "$password" | base64 | tr -d '\n')"
  ( umask 077; printf '{"auths":{"%s":{"auth":"%s"}}}\n' "$host" "$b64" > "$dir/config.json" )
  # The image-tool runs as root (--user 0) but make it readable regardless.
  chmod 755 "$dir"; chmod 644 "$dir/config.json"
  echo "$dir"
}
