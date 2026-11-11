# Hkit

> This English README describes Hkit 1.0.1. The Chinese [README.md](README.md) covers 1.0.2, which adds Debian 12/13 and Ubuntu 22.04 support and the `hkit` management command.

Hkit is the public, signature-verifying installer for the private Hkit Core.
It does not contain the Core source code or its Git history.

## Security model

The installer is pinned to Hkit `1.0.1` and Minisign key
`A7178F5CF94B2F7D`. Before any Core installer code runs it verifies:

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

## Install Hkit 1.0.1

On a clean Ubuntu 24.04 x86_64 server, install `curl` if it is not already
available, then run the version-pinned URL installer:

```bash
curl -fsSL https://raw.githubusercontent.com/hcloudlab/Hkit/v1.0.4/install.sh | \
  sudo bash -s -- --public-ipv4 YOUR_PUBLIC_IPV4
```

Select protocols through the same verified installer:

```bash
curl -fsSL https://raw.githubusercontent.com/hcloudlab/Hkit/v1.0.4/install.sh | \
  sudo bash -s -- --public-ipv4 YOUR_PUBLIC_IPV4 --protocols reality,xhttp
```

The bootstrap URL is pinned to the immutable `v1.0.4` tag rather than
`main`. The bootstrap retrieves its public key, verifier, and three release
assets from that same fixed version, verifies their pinned identities and the
formal Minisign signature, and only then executes the packaged Core installer.
It installs missing Ubuntu runtime dependencies through `apt` when necessary.

For development or offline inspection, clone the matching tag and invoke
`sudo ./install.sh` with the same arguments.

When UFW or firewalld is active, the installer adds allow rules for the
installed protocol ports (and TCP 2096 and 80 for the subscription). It never
enables or resets a firewall or changes default policies, and leaves custom
nftables/iptables rules alone. Added rules are recorded in
`/etc/hkit/firewall-rules` and `hkit uninstall` removes only those. Use
`--no-firewall` to skip this step. Cloud security groups still have to be
opened in your provider's console.

## Release mapping

[`versions.json`](versions.json) records the public version, exact private Core
commit, archive format, and signing key identity. Release operators should
follow [`docs/releasing.md`](docs/releasing.md).
