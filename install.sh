#!/usr/bin/env bash
set -euo pipefail

readonly HKIT_VERSION="1.0.1"
readonly HKIT_RELEASE_BASE_URL="https://github.com/hcloudlab/Hkit/releases/download/v${HKIT_VERSION}"
readonly HKIT_PUBLIC_SOURCE_BASE_URL="https://raw.githubusercontent.com/hcloudlab/Hkit/v${HKIT_VERSION}"
readonly HKIT_PUBLIC_KEY_SHA256="de9828796091fad0a1568ec1af2f5f4825c97b50675d84228991f83177f36e74"
readonly HKIT_PUBLIC_VERIFIER_SHA256="26fa6ab3e1634a8e0c0758c3659f5f15ca8e31ac316bc950e1dfd1275d1a1c2a"
SCRIPT_DIR=""
if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" && ! -L "${BASH_SOURCE[0]}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
readonly SCRIPT_DIR
HKIT_BOOTSTRAP_WORK_DIR=""

installer_error() {
  printf 'hkit_bootstrap_error:%s:%s\n' "$1" "$2" >&2
  return 1
}

installer_require_root() {
  [[ "$(id -u)" -eq 0 ]] || installer_error root_required "run this installer as root"
}

installer_missing_commands() {
  local command_name missing=""
  for command_name in "$@"; do
    command -v "$command_name" >/dev/null 2>&1 || {
      missing+=" $command_name"
    }
  done
  printf '%s\n' "$missing"
}

installer_require_bootstrap_dependencies() {
  local missing
  missing="$(installer_missing_commands awk curl id install minisign mktemp python3 sha256sum)"
  [[ -z "$missing" ]] || {
    installer_error dependency_missing "missing commands:$missing; on Ubuntu run: apt-get update && apt-get install -y ca-certificates coreutils curl iproute2 jq libdigest-sha-perl minisign openssl passwd python3 systemd util-linux"
    return 1
  }
}

installer_prepare_dependencies() {
  local bootstrap_missing runtime_missing
  bootstrap_missing="$(installer_missing_commands awk curl id install minisign mktemp python3 sha256sum)"
  runtime_missing="$(installer_missing_commands base64 flock groupadd jq openssl readlink sed shasum ss systemctl useradd)"
  [[ -z "$bootstrap_missing$runtime_missing" ]] && return 0
  if ! command -v apt-get >/dev/null 2>&1 || [[ ! -r /etc/os-release ]]; then
    installer_require_bootstrap_dependencies
    return
  fi
  # shellcheck disable=SC1091
  source /etc/os-release
  if [[ "${ID:-}" != ubuntu ]]; then
    installer_require_bootstrap_dependencies
    return
  fi
  printf 'Installing required Hkit packages on Ubuntu...\n'
  apt-get update || {
    installer_error dependency_install_failed "apt-get update failed"
    return 1
  }
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    ca-certificates coreutils curl iproute2 jq libdigest-sha-perl minisign \
    openssl passwd python3 systemd util-linux || {
    installer_error dependency_install_failed "apt-get could not install required packages"
    return 1
  }
  installer_require_bootstrap_dependencies
  [[ -z "$(installer_missing_commands base64 flock groupadd jq openssl readlink sed shasum ss systemctl useradd)" ]] || {
    installer_error dependency_install_failed "Ubuntu runtime commands remain unavailable after package installation"
    return 1
  }
}

installer_cleanup() {
  if [[ -n "$HKIT_BOOTSTRAP_WORK_DIR" && -d "$HKIT_BOOTSTRAP_WORK_DIR" && ! -L "$HKIT_BOOTSTRAP_WORK_DIR" ]]; then
    command rm -rf -- "$HKIT_BOOTSTRAP_WORK_DIR"
  fi
}

installer_download_url() {
  local url="$1" destination="$2" label="$3"
  curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 \
    --retry 3 --retry-all-errors --output "$destination" \
    "$url" || {
      installer_error download_failed "failed to download $label for Hkit $HKIT_VERSION"
      return 1
    }
}

installer_download() {
  local name="$1" destination="$2"
  installer_download_url "$HKIT_RELEASE_BASE_URL/$name" "$destination" "$name"
}

installer_hash_file() {
  local path="$1"
  sha256sum "$path" | awk '{print $1}'
}

installer_prepare_public_file() {
  local relative="$1" destination="$2" expected_sha="$3" local_source=""
  if [[ -n "$SCRIPT_DIR" ]]; then
    local_source="$SCRIPT_DIR/$relative"
  fi
  if [[ -n "$local_source" && -f "$local_source" && ! -L "$local_source" ]]; then
    install -m 0400 "$local_source" "$destination"
  else
    installer_download_url "$HKIT_PUBLIC_SOURCE_BASE_URL/$relative" "$destination" "$relative"
    chmod 0400 "$destination"
  fi
  [[ "$(installer_hash_file "$destination")" == "$expected_sha" ]] || {
    installer_error public_file_mismatch "$relative differs from the pinned Hkit $HKIT_VERSION file"
    return 1
  }
}

main() {
  local bundle_dir extract_dir trusted_key verifier key_sha asset
  installer_require_root
  installer_prepare_dependencies

  HKIT_BOOTSTRAP_WORK_DIR="$(mktemp -d /tmp/hkit-bootstrap.XXXXXX)"
  trap installer_cleanup EXIT
  bundle_dir="$HKIT_BOOTSTRAP_WORK_DIR/release"
  extract_dir="$HKIT_BOOTSTRAP_WORK_DIR/extracted"
  mkdir -m 0700 "$bundle_dir"
  trusted_key="$bundle_dir/hkit-core.pub"
  verifier="$bundle_dir/verify_release.py"
  installer_prepare_public_file keys/hkit-core.pub "$trusted_key" "$HKIT_PUBLIC_KEY_SHA256"
  installer_prepare_public_file lib/verify_release.py "$verifier" "$HKIT_PUBLIC_VERIFIER_SHA256"
  key_sha="$(installer_hash_file "$trusted_key")"
  [[ "$key_sha" == "$HKIT_PUBLIC_KEY_SHA256" ]] || {
    installer_error trusted_key_mismatch "the pinned Hkit public key differs"
    return 1
  }
  for asset in manifest.json manifest.json.minisig hkit-core.tar; do
    installer_download "$asset" "$bundle_dir/$asset"
  done

  minisign -Vm "$bundle_dir/manifest.json" \
    -x "$bundle_dir/manifest.json.minisig" -p "$trusted_key" -q >/dev/null 2>&1 || {
      installer_error signature_invalid "the Hkit release manifest signature is invalid"
      return 1
    }
  python3 "$verifier" \
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
