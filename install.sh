#!/usr/bin/env bash
set -euo pipefail

readonly HKIT_VERSION="1.0.0"
readonly HKIT_RELEASE_BASE_URL="https://github.com/hcloudlab/Hkit/releases/download/v${HKIT_VERSION}"
readonly HKIT_PUBLIC_KEY_SHA256="2a4933c0d1b48811bc7c17baff28c17558d342f3ccc091b1133b5c81c4c01c04"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
HKIT_BOOTSTRAP_WORK_DIR=""

installer_error() {
  printf 'hkit_bootstrap_error:%s:%s\n' "$1" "$2" >&2
  return 1
}

installer_require_root() {
  [[ "$(id -u)" -eq 0 ]] || installer_error root_required "run this installer as root"
}

installer_require_dependencies() {
  local command_name
  for command_name in awk curl install minisign mktemp python3 shasum; do
    command -v "$command_name" >/dev/null 2>&1 || {
      installer_error dependency_missing "$command_name is required"
      return 1
    }
  done
}

installer_cleanup() {
  if [[ -n "$HKIT_BOOTSTRAP_WORK_DIR" && -d "$HKIT_BOOTSTRAP_WORK_DIR" && ! -L "$HKIT_BOOTSTRAP_WORK_DIR" ]]; then
    command rm -rf -- "$HKIT_BOOTSTRAP_WORK_DIR"
  fi
}

installer_download() {
  local name="$1" destination="$2"
  curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 \
    --retry 3 --retry-all-errors --output "$destination" \
    "$HKIT_RELEASE_BASE_URL/$name" || {
      installer_error download_failed "failed to download $name for Hkit $HKIT_VERSION"
      return 1
    }
}

main() {
  local bundle_dir extract_dir trusted_key key_sha asset
  installer_require_root
  installer_require_dependencies
  [[ -f "$SCRIPT_DIR/keys/hkit-core.pub" && ! -L "$SCRIPT_DIR/keys/hkit-core.pub" ]] || {
    installer_error trusted_key_missing "the pinned Hkit public key is missing"
    return 1
  }
  [[ -f "$SCRIPT_DIR/lib/verify_release.py" && ! -L "$SCRIPT_DIR/lib/verify_release.py" ]] || {
    installer_error verifier_missing "the Hkit release verifier is missing"
    return 1
  }

  key_sha="$(shasum -a 256 "$SCRIPT_DIR/keys/hkit-core.pub" | awk '{print $1}')"
  [[ "$key_sha" == "$HKIT_PUBLIC_KEY_SHA256" ]] || {
    installer_error trusted_key_mismatch "the pinned Hkit public key differs"
    return 1
  }

  HKIT_BOOTSTRAP_WORK_DIR="$(mktemp -d /tmp/hkit-bootstrap.XXXXXX)"
  trap installer_cleanup EXIT
  bundle_dir="$HKIT_BOOTSTRAP_WORK_DIR/release"
  extract_dir="$HKIT_BOOTSTRAP_WORK_DIR/extracted"
  mkdir -m 0700 "$bundle_dir"
  trusted_key="$bundle_dir/hkit-core.pub"
  install -m 0644 "$SCRIPT_DIR/keys/hkit-core.pub" "$trusted_key"
  for asset in manifest.json manifest.json.minisig hkit-core.tar; do
    installer_download "$asset" "$bundle_dir/$asset"
  done

  minisign -Vm "$bundle_dir/manifest.json" \
    -x "$bundle_dir/manifest.json.minisig" -p "$trusted_key" -q >/dev/null 2>&1 || {
      installer_error signature_invalid "the Hkit release manifest signature is invalid"
      return 1
    }
  python3 "$SCRIPT_DIR/lib/verify_release.py" \
    "$bundle_dir/manifest.json" "$bundle_dir/hkit-core.tar" "$HKIT_VERSION" "$extract_dir" || {
      installer_error release_invalid "the signed Hkit release failed integrity validation"
      return 1
    }

  "$extract_dir/installer/hkit-install.sh" \
    --release-source "$bundle_dir" \
    --release-version "$HKIT_VERSION" \
    --trust-key "$trusted_key" \
    "$@"
}

main "$@"
