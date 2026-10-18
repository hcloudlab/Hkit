# Hkit

Hkit is the public, signature-verifying installer for the private Hkit Core.
It does not contain the Core source code or its Git history.

## Security model

The installer is pinned to Hkit `1.0.0` and Minisign key
`F4CA29FD4BAD4169`. Before any Core installer code runs it verifies:

1. the detached Minisign signature on `manifest.json`;
2. the manifest schema, product, version, and release format;
3. the SHA-256 and byte size of `hkit-core.tar`;
4. the exact archive member set and safe regular-file types;
5. the `release.json` release/component binding.

The private signing key is never stored in this repository or in a public
release. Public releases contain exactly:

- `manifest.json`
- `manifest.json.minisig`
- `hkit-core.tar`

## Install Hkit 1.0

The `v1.0.0` tag and matching GitHub Release must exist before this command is
usable. On a clean Ubuntu 24.04 x86_64 server:

```bash
sudo apt-get update
sudo apt-get install -y curl jq minisign openssl python3 iproute2
git clone --depth 1 --branch v1.0.0 https://github.com/hcloudlab/Hkit.git
cd Hkit
sudo ./install.sh --public-ipv4 YOUR_PUBLIC_IPV4
```

Protocol selection remains available through the verified Core installer:

```bash
sudo ./install.sh \
  --public-ipv4 YOUR_PUBLIC_IPV4 \
  --protocols reality,xhttp
```

The installer does not automatically modify UFW or a cloud firewall. After a
successful installation it prints the exact selected protocol ports and the
corresponding UFW commands.

## Release mapping

[`versions.json`](versions.json) records the public version, exact private Core
commit, archive format, and signing key identity. Release operators should
follow [`docs/releasing.md`](docs/releasing.md).
