# Hkit 1.0 release procedure

## Repository boundary

- `hcloudlab/Hkit-core` is private and is the only Core source repository.
- `hcloudlab/Hkit` is public and contains only the bootstrap installer,
  verifier, public key, version mapping, documentation, and tests.
- The public GitHub Release receives the three signed release-contract files;
  it does not receive the private repository or signing key.

## Required GitHub configuration

Create a protected GitHub Environment named `production-release` in
`hcloudlab/Hkit-core` with a required reviewer. Configure these environment
secrets:

- `HKIT_PUBLIC_RELEASE_TOKEN`: fine-grained token restricted to
  `hcloudlab/Hkit`, with repository Contents read/write permission only.
- `HKIT_MINISIGN_SECRET_KEY_B64`: base64 encoding of the encrypted Minisign
  secret-key file.
- `HKIT_MINISIGN_PASSWORD`: password for that encrypted key.

The workflow's normal `GITHUB_TOKEN` remains read-only and cannot publish to
the public repository. Do not use an organization-wide classic token.

## Manual release gate

The private workflow `.github/workflows/release-public.yml` is manual. It:

1. requires the exact approved Core commit;
2. downloads the five pinned official Linux x86_64 component assets;
3. checks every pinned SHA-256 before extraction;
4. builds release format 2 with the production builder;
5. verifies the signature and archive contract again;
6. checks out the public repository and verifies its `versions.json` mapping;
7. creates a **draft** public release containing exactly the three assets.

Creating or publishing the final `v1.0.0` tag/release is a human approval
step. The workflow must not be run until the environment and secrets above are
configured and the public installer commit is reviewed.

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
python3 lib/verify_release.py manifest.json hkit-core.tar 1.0.0 extracted
```

Only publish after both commands pass and the public tag points at the reviewed
installer commit.
