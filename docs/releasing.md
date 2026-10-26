# Hkit 1.0.1 release procedure

## Repository boundary

- `hcloudlab/Hkit-core` is private and is the only Core source repository.
- `hcloudlab/Hkit` is public and contains only the bootstrap installer,
  verifier, public key, version mapping, documentation, and tests.
- The public GitHub Release receives the three signed release-contract files;
  it does not receive the private repository or signing key.

## Formal signing identity

Hkit 1.0.x trusts Minisign key `A7178F5CF94B2F7D`. The matching public key in
`keys/hkit-core.pub` has SHA-256
`de9828796091fad0a1568ec1af2f5f4825c97b50675d84228991f83177f36e74`.

The encrypted private key exists only on the release operator's local Mac.
GitHub Actions performs credential-free build and validation with an ephemeral
test key; it never receives the formal private key, its password, or a
production release token. Formal signing and Draft Release upload are separate
local operations documented in Hkit-core.

The former key `F4CA29FD4BAD4169` was retired before any Hkit 1.0 Tag or Release
was published. Its local files are retained for audit only and must not sign a
Hkit 1.0 release.

## Manual release gate

The private workflow `.github/workflows/release-public.yml` is credential-free.
It:

1. requires the exact approved Core commit;
2. downloads the five pinned official Linux x86_64 component assets;
3. checks every pinned SHA-256 before extraction;
4. builds release format 2 with the production builder;
5. verifies the ephemeral signature and archive contract again;
6. checks out the public repository and verifies its `versions.json` mapping;
7. creates immutable validation evidence without publishing a release.

The reviewed Core release tools then build and sign locally with the encrypted
formal key. Creating or publishing the final `v1.0.1` tag/release remains a
separate human-approved step. No GitHub-hosted workflow may sign or publish it.

## Release assets

The draft release must contain exactly:

```text
manifest.json
manifest.json.minisig
hkit-core.tar
```

Before publishing, download the draft assets into a clean directory and run:

```bash
minisign -Vm manifest.json -x manifest.json.minisig -p keys/hkit-core.pub
python3 lib/verify_release.py manifest.json hkit-core.tar 1.0.1 extracted
```

Only publish after both commands pass and the public tag points at the reviewed
installer commit.

The `v1.0.0` release and its assets are immutable history. Version `1.0.1`
keeps the same signing identity and component versions while correcting the
Format 2 installer dependency closure. The public URL command must reference
the fixed `v1.0.1` tag, never the floating `main` branch.
