#!/usr/bin/env python3
"""Verify and extract the installer payload from a signed Hkit release."""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import sys
import tarfile
from typing import Any


COMPONENTS = ("xray", "hysteria2", "mieru", "sing-box", "caddy")
INSTALLER_FILES = (
    "hkit-install.sh",
    "lib/constants.sh",
    "lib/hkit_artifacts.sh",
    "lib/hkit_commit_health.sh",
    "lib/hkit_install.sh",
    "lib/hkit_inventory.sh",
    "lib/hkit_paths.sh",
    "lib/hkit_release.sh",
    "lib/hkit_release_package.py",
    "lib/hkit_release_verify.sh",
    "lib/hkit_renderer_mihomo.sh",
    "lib/hkit_renderer_sing_box.sh",
    "lib/hkit_renderer_uri.sh",
    "lib/hkit_resources.sh",
    "lib/hkit_runtime.sh",
    "lib/hkit_service_provision.sh",
    "lib/hkit_start_health.sh",
    "lib/hkit_state_store.sh",
    "lib/hkit_state_v1.sh",
    "lib/hkit_update_prepare.sh",
    "lib/hysteria2.sh",
)
HASH_RE = re.compile(r"^[0-9a-f]{64}$")
VERSION_RE = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+(?:-[A-Za-z0-9][A-Za-z0-9.-]{0,31})?$")
COMPONENT_VERSION_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$")
MAX_ARCHIVE_SIZE = 1024 * 1024 * 1024


class VerificationError(ValueError):
    pass


def reject_duplicates(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise VerificationError("duplicate JSON key")
        result[key] = value
    return result


def load_json(path: Path) -> Any:
    try:
        with path.open("r", encoding="utf-8") as stream:
            return json.load(stream, object_pairs_hook=reject_duplicates)
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise VerificationError("invalid JSON") from error


def require_keys(value: Any, expected: set[str]) -> None:
    if not isinstance(value, dict) or set(value) != expected:
        raise VerificationError("unexpected JSON fields")


def validate_manifest(path: Path, requested_version: str) -> dict[str, Any]:
    manifest = load_json(path)
    require_keys(manifest, {"manifest_schema", "product", "release", "artifact", "components"})
    if (
        isinstance(manifest["manifest_schema"], bool)
        or manifest["manifest_schema"] != 1
        or manifest["product"] != "hkit-core"
    ):
        raise VerificationError("unsupported manifest")
    release = manifest["release"]
    require_keys(release, {"id", "version", "format_schema", "state_schema_min", "state_schema_max"})
    if (
        release["version"] != requested_version
        or not isinstance(requested_version, str)
        or not VERSION_RE.fullmatch(requested_version)
        or release["id"] != f"rel-{requested_version}"
        or any(
            isinstance(release[field], bool) or not isinstance(release[field], int)
            for field in ("format_schema", "state_schema_min", "state_schema_max")
        )
        or release["format_schema"] != 2
        or release["state_schema_min"] != 1
        or release["state_schema_max"] != 1
    ):
        raise VerificationError("release binding mismatch")
    artifact = manifest["artifact"]
    require_keys(artifact, {"filename", "sha256", "size"})
    if (
        artifact["filename"] != "hkit-core.tar"
        or not isinstance(artifact["sha256"], str)
        or not HASH_RE.fullmatch(artifact["sha256"])
        or isinstance(artifact["size"], bool)
        or not isinstance(artifact["size"], int)
        or not 0 < artifact["size"] <= MAX_ARCHIVE_SIZE
    ):
        raise VerificationError("invalid artifact metadata")
    components = manifest["components"]
    require_keys(components, set(COMPONENTS))
    for version in components.values():
        if not isinstance(version, str) or not COMPONENT_VERSION_RE.fullmatch(version) or ".." in version:
            raise VerificationError("invalid component version")
    return manifest


def expected_files(manifest: dict[str, Any]) -> set[str]:
    files = {"release/release.json", "release/hkit"}
    for component in COMPONENTS:
        version = manifest["components"][component]
        files.add(f"components/{component}/{version}/{component}")
    files.update(f"installer/{relative}" for relative in INSTALLER_FILES)
    return files


def safe_name(member: tarfile.TarInfo) -> str:
    path = PurePosixPath(member.name)
    if path.is_absolute() or any(part in {"", ".", ".."} for part in path.parts):
        raise VerificationError("unsafe archive path")
    return path.as_posix()


def validate_release_json(data: bytes, manifest: dict[str, Any]) -> None:
    try:
        metadata = json.loads(data.decode("utf-8"), object_pairs_hook=reject_duplicates)
    except (UnicodeError, json.JSONDecodeError) as error:
        raise VerificationError("invalid release metadata") from error
    require_keys(
        metadata,
        {"schema_version", "release_id", "release_version", "state_schema_version", "directory", "components"},
    )
    version = manifest["release"]["version"]
    if metadata != {
        "schema_version": 1,
        "release_id": f"rel-{version}",
        "release_version": version,
        "state_schema_version": 1,
        "directory": f"/opt/hkit/releases/{version}",
        "components": {
            component: {
                "version": manifest["components"][component],
                "path": f"/opt/hkit/components/{component}/{manifest['components'][component]}/{component}",
            }
            for component in COMPONENTS
        },
    }:
        raise VerificationError("release metadata differs from manifest")


def verify_and_extract(manifest_path: Path, archive_path: Path, version: str, destination: Path) -> None:
    manifest = validate_manifest(manifest_path, version)
    if archive_path.is_symlink() or not archive_path.is_file():
        raise VerificationError("archive is not a regular file")
    if archive_path.stat().st_size != manifest["artifact"]["size"]:
        raise VerificationError("archive size mismatch")
    digest = hashlib.sha256()
    with archive_path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    if digest.hexdigest() != manifest["artifact"]["sha256"]:
        raise VerificationError("archive digest mismatch")
    if destination.exists() or destination.is_symlink():
        raise VerificationError("extraction destination already exists")

    expected = expected_files(manifest)
    seen: set[str] = set()
    installer_members: list[tarfile.TarInfo] = []
    try:
        with tarfile.open(archive_path, mode="r:") as archive:
            for member in archive.getmembers():
                name = safe_name(member)
                if name in seen or not member.isfile() or member.pax_headers or name not in expected:
                    raise VerificationError("unsafe or unexpected archive member")
                seen.add(name)
                if name.startswith("installer/"):
                    installer_members.append(member)
            if seen != expected:
                raise VerificationError("archive member set mismatch")
            release_member = archive.getmember("release/release.json")
            release_stream = archive.extractfile(release_member)
            if release_stream is None:
                raise VerificationError("release metadata cannot be read")
            validate_release_json(release_stream.read(), manifest)

            destination.mkdir(mode=0o700)
            (destination / "installer").mkdir(mode=0o700)
            (destination / "installer/lib").mkdir(mode=0o700)
            for member in installer_members:
                source = archive.extractfile(member)
                if source is None:
                    raise VerificationError("installer member cannot be read")
                target = destination / safe_name(member)
                flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
                file_mode = 0o500 if member.name in {
                    "installer/hkit-install.sh",
                    "installer/lib/hkit_release_package.py",
                } else 0o400
                descriptor = os.open(target, flags, file_mode)
                try:
                    with os.fdopen(os.dup(descriptor), "wb") as output:
                        shutil.copyfileobj(source, output, length=1024 * 1024)
                        output.flush()
                    os.fsync(descriptor)
                finally:
                    os.close(descriptor)
                os.chmod(target, file_mode)
    except (OSError, tarfile.TarError) as error:
        raise VerificationError("archive cannot be safely processed") from error


def main(argv: list[str]) -> int:
    if len(argv) != 5:
        print("usage: verify_release.py MANIFEST ARCHIVE VERSION DESTINATION", file=sys.stderr)
        return 2
    try:
        verify_and_extract(Path(argv[1]), Path(argv[2]), argv[3], Path(argv[4]))
        return 0
    except VerificationError as error:
        print(f"hkit_public_verifier_error:{error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
