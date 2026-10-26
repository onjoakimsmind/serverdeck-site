# serverdeck-site

The public landing page and install bootstrap for
[ServerDeck](https://github.com/onjoakimsmind/serverdeck), served at
<https://serverdeck.black.ax> and deployed by Dokploy directly from this
repository. It is a static nginx image with no runtime application
dependencies.

## Files

- `public/index.html` — landing page
- `public/styles.css` — self-hosted design system and responsive layout
- `public/site.js` — copy buttons, mobile navigation, and live GitHub release metadata
- `public/install.sh` — bootstrap installer served at `/install.sh`
- `nginx.conf` — unprivileged nginx configuration, security headers, and cache rules
- `Dockerfile` — the image deployed by Dokploy

Fonts are bundled under `public/assets/fonts` under the SIL Open Font License;
their license texts sit next to the font files.

## Installer

`public/install.sh` is intentionally independent from ServerDeck's own
`packaging/install.sh`. It resolves the latest stable GitHub release of
[onjoakimsmind/serverdeck](https://github.com/onjoakimsmind/serverdeck),
downloads the x86_64 tarball and its SHA-256 checksum, verifies the archive,
extracts it, and invokes the release installer with `sudo`. Arguments are
forwarded, so this also works:

```sh
curl -fsSL https://serverdeck.black.ax/install.sh | sh -s -- --workloads docker
```

The release tarball's own installer verifies its internal `SHA256SUMS` again
before changing the host.

## Build locally

```sh
docker build -t serverdeck-site .
docker run --rm -p 8081:8080 serverdeck-site
```

Then open <http://127.0.0.1:8081>. The container runs as the unprivileged
`nginx` user on port 8080.

## Deployment

Dokploy builds `Dockerfile` at the repository root against this repository's
`main` branch and serves it at `serverdeck.black.ax` on container port 8080,
behind a Cloudflare-proxied domain with DNS-01 TLS.
