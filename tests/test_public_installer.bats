#!/usr/bin/env bats

setup() {
  export TEST_REPO="$BATS_TEST_TMPDIR/public"
  export TEST_RELEASE="$BATS_TEST_TMPDIR/release"
  export TEST_BIN="$BATS_TEST_TMPDIR/bin"
  export TEST_CAPTURE="$BATS_TEST_TMPDIR/core-arguments"
  cp -R "$BATS_TEST_DIRNAME/.." "$TEST_REPO"
  mkdir -p "$TEST_RELEASE" "$TEST_BIN"
  minisign -G -W -s "$BATS_TEST_TMPDIR/test.key" -p "$BATS_TEST_TMPDIR/test.pub" >/dev/null 2>&1
  cp "$BATS_TEST_TMPDIR/test.pub" "$TEST_REPO/keys/hkit-core.pub"
  key_sha="$(shasum -a 256 "$TEST_REPO/keys/hkit-core.pub" | awk '{print $1}')"
  python3 - "$TEST_REPO/install.sh" "$key_sha" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
text = path.read_text()
text = re.sub(r'readonly HKIT_PUBLIC_KEY_SHA256="[0-9a-f]{64}"',
              f'readonly HKIT_PUBLIC_KEY_SHA256="{sys.argv[2]}"', text)
path.write_text(text)
PY
  build_fixture
  minisign -S -s "$BATS_TEST_TMPDIR/test.key" -m "$TEST_RELEASE/manifest.json" \
    -x "$TEST_RELEASE/manifest.json.minisig" -q >/dev/null 2>&1
  make_command_mocks
}

build_fixture() {
  python3 - "$TEST_REPO/lib/verify_release.py" "$TEST_RELEASE" <<'PY'
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import sys
import tarfile

spec = importlib.util.spec_from_file_location("verifier", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
root = Path(sys.argv[2])
components = {"xray":"26.7.28","hysteria2":"2.6.5","mieru":"3.37.0","sing-box":"1.12.0","caddy":"2.10.2"}
release = {
    "schema_version":1,"release_id":"rel-1.0.0","release_version":"1.0.0",
    "state_schema_version":1,"directory":"/opt/hkit/releases/1.0.0",
    "components":{name:{"version":version,"path":f"/opt/hkit/components/{name}/{version}/{name}"}
                  for name, version in components.items()},
}
files = {"release/release.json": json.dumps(release, sort_keys=True).encode(), "release/hkit":b"release\n"}
for name, version in components.items():
    files[f"components/{name}/{version}/{name}"] = b"component\n"
for relative in module.INSTALLER_FILES:
    data = b"placeholder\n"
    if relative == "hkit-install.sh":
        data = b'#!/usr/bin/env bash\nprintf "%s\\n" "$@" > "$TEST_CAPTURE"\n'
    files[f"installer/{relative}"] = data
archive_path = root / "hkit-core.tar"
with tarfile.open(archive_path, "w", format=tarfile.USTAR_FORMAT) as archive:
    for name in sorted(files):
        member = tarfile.TarInfo(name)
        member.size = len(files[name])
        member.mode = 0o500 if name in {"release/hkit","installer/hkit-install.sh","installer/lib/hkit_release_package.py"} or name.startswith("components/") else 0o400
        member.mtime = member.uid = member.gid = 0
        archive.addfile(member, io.BytesIO(files[name]))
content = archive_path.read_bytes()
manifest = {
    "manifest_schema":1,"product":"hkit-core",
    "release":{"id":"rel-1.0.0","version":"1.0.0","format_schema":2,"state_schema_min":1,"state_schema_max":1},
    "artifact":{"filename":"hkit-core.tar","sha256":hashlib.sha256(content).hexdigest(),"size":len(content)},
    "components":components,
}
(root / "manifest.json").write_text(json.dumps(manifest, sort_keys=True, separators=(",",":"))+"\n")
PY
}

make_command_mocks() {
  cat > "$TEST_BIN/id" <<'SH'
#!/usr/bin/env bash
[[ "$1" == -u ]] && printf '0\n'
SH
  cat > "$TEST_BIN/curl" <<'SH'
#!/usr/bin/env bash
destination=""
url=""
while (($#)); do
  if [[ "$1" == --output ]]; then destination="$2"; shift 2; continue; fi
  url="$1"
  shift
done
cp "$TEST_RELEASE/${url##*/}" "$destination"
SH
  chmod +x "$TEST_BIN/id" "$TEST_BIN/curl"
}

run_installer() {
  run env PATH="$TEST_BIN:$PATH" TEST_CAPTURE="$TEST_CAPTURE" TEST_RELEASE="$TEST_RELEASE" \
    "$TEST_REPO/install.sh" --public-ipv4 203.0.113.10 --protocols anytls
}

@test "signed format 2 release reaches the verified Core installer" {
  run_installer
  [ "$status" -eq 0 ]
  [ "$(sed -n '1p' "$TEST_CAPTURE")" = --release-source ]
  [ "$(sed -n '3p' "$TEST_CAPTURE")" = --release-version ]
  [ "$(sed -n '4p' "$TEST_CAPTURE")" = 1.0.0 ]
  [ "$(sed -n '5p' "$TEST_CAPTURE")" = --trust-key ]
  grep -Fx -- 203.0.113.10 "$TEST_CAPTURE"
  grep -Fx -- anytls "$TEST_CAPTURE"
}

@test "download failure stops before Core execution" {
  printf '#!/usr/bin/env bash\nexit 22\n' > "$TEST_BIN/curl"
  chmod +x "$TEST_BIN/curl"
  run_installer
  [ "$status" -ne 0 ]
  [[ "$output" == *"hkit_bootstrap_error:download_failed"* ]]
  [ ! -e "$TEST_CAPTURE" ]
}

@test "invalid signature stops before archive processing" {
  printf '\n' >> "$TEST_RELEASE/manifest.json"
  run_installer
  [ "$status" -ne 0 ]
  [[ "$output" == *"hkit_bootstrap_error:signature_invalid"* ]]
  [ ! -e "$TEST_CAPTURE" ]
}

@test "signed manifest with a mismatched archive is rejected" {
  printf 'tamper' >> "$TEST_RELEASE/hkit-core.tar"
  run_installer
  [ "$status" -ne 0 ]
  [[ "$output" == *"hkit_bootstrap_error:release_invalid"* ]]
  [ ! -e "$TEST_CAPTURE" ]
}

@test "signed release with an unexpected archive member is rejected" {
  python3 - "$TEST_RELEASE" <<'PY'
import hashlib
import io
import json
from pathlib import Path
import sys
import tarfile

root = Path(sys.argv[1])
archive_path = root / "hkit-core.tar"
with tarfile.open(archive_path, "a") as archive:
    data = b"unexpected\n"
    member = tarfile.TarInfo("README")
    member.size = len(data)
    archive.addfile(member, io.BytesIO(data))
content = archive_path.read_bytes()
manifest_path = root / "manifest.json"
manifest = json.loads(manifest_path.read_text())
manifest["artifact"]["sha256"] = hashlib.sha256(content).hexdigest()
manifest["artifact"]["size"] = len(content)
manifest_path.write_text(json.dumps(manifest, sort_keys=True, separators=(",",":"))+"\n")
PY
  rm "$TEST_RELEASE/manifest.json.minisig"
  minisign -S -s "$BATS_TEST_TMPDIR/test.key" -m "$TEST_RELEASE/manifest.json" \
    -x "$TEST_RELEASE/manifest.json.minisig" -q >/dev/null 2>&1
  run_installer
  [ "$status" -ne 0 ]
  [[ "$output" == *"hkit_bootstrap_error:release_invalid"* ]]
  [ ! -e "$TEST_CAPTURE" ]
}
