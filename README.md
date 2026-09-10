# Tailscale DERP Server Container (`ts-derp`)

A minimal, secure containerization of Tailscale's DERP (Designated Encrypted Relay for Packets) relay server ([`tailscale.com/cmd/derper`](https://pkg.go.dev/tailscale.com/cmd/derper)).

## Features

- **Minimal `scratch` Image with Root CA Certificates**: Multi-stage build that compiles a statically linked Go binary (`CGO_ENABLED=0`) with symbol/DWARF stripping (`-s -w -extldflags '-static'`). Includes the system CA certificate bundle (`/etc/ssl/certs/ca-certificates.crt`) to enable outbound TLS certificate verification without bringing along an OS userspace.
- **Built-in ACME / Let's Encrypt TLS Automation**: Leverages `derper`'s native ACME functionality to automatically request, verify, and renew valid TLS certificates from Let's Encrypt for your configured `--hostname`.
- **Multi-Architecture Support**: Built with `--platform=$BUILDPLATFORM` cross-compilation for native fast builds targeting both `linux/amd64` and `linux/arm64`.
- **Automated Dependency Updates via Dependabot**:
  - Pinned and tracked natively via the Go `tool` directive in [go.mod](file:///home/pants/Projects/container_projects/ts-derp/go.mod).
  - Dependabot polls daily for new releases of `tailscale.com`.
  - Automatically raises PRs when new Tailscale versions are available.
- **CI/CD with GitHub Actions**: Multi-arch build pipeline that tests the container and pushes to GitHub Container Registry (`ghcr.io`).

---

## Repository Structure

- [Dockerfile](file:///home/pants/Projects/container_projects/ts-derp/Dockerfile): Multi-stage build compiling static `derper` and packaging into `scratch` with root CA certificates.
- [go.mod](file:///home/pants/Projects/container_projects/ts-derp/go.mod) & [go.sum](file:///home/pants/Projects/container_projects/ts-derp/go.sum): Tracks the exact version of Tailscale and pins `tool tailscale.com/cmd/derper`.
- [.github/dependabot.yml](file:///home/pants/Projects/container_projects/ts-derp/.github/dependabot.yml): Configures daily Go module updates and weekly Docker/Actions updates.
- [.github/workflows/build.yml](file:///home/pants/Projects/container_projects/ts-derp/.github/workflows/build.yml): GitHub Actions workflow for build, test, and container registry publishing.
- [compose.yaml](file:///home/pants/Projects/container_projects/ts-derp/compose.yaml): Example Docker Compose configuration with volume mounting for cert persistence.

---

## TLS Certificates and ACME Automation

`derper` comes with built-in ACME client functionality to automatically obtain and renew free, trusted TLS certificates from Let's Encrypt.

### How it works

1. **Root CA Verification**: The container image contains the updated CA certificate bundle (`/etc/ssl/certs/ca-certificates.crt`), allowing `derper` to securely communicate with Let's Encrypt's ACME directory (`https://acme-v02.api.letsencrypt.org/directory`) over TLS.
2. **HTTP-01 Challenge**: When clients connect to your DERP server, `derper` negotiates certificates using the ACME HTTP-01 challenge. Let's Encrypt sends an HTTP verification request to port `80` at your configured `--hostname`.
3. **Certificate Caching**: Issued certificates and account keys are saved to `--certdir` (mounted to `./certs` on the host). Reusing cached certificates prevents hitting Let's Encrypt rate limits when restarting the container.
4. **Automatic Renewal**: `derper` handles background renewal checks automatically before certificates expire.

### Requirements

- **DNS Record**: A public DNS `A`/`AAAA` record pointing your domain (e.g., `derp.example.com`) to your server's public IP address.
- **Port 80 TCP**: Must be open to the public internet for HTTP-01 ACME challenges.
- **Port 443 TCP**: Must be open for HTTPS DERP relay traffic.
- **Port 3478 UDP**: Must be open for STUN (Session Traversal Utilities for NAT).

---

## Building Locally

### Build single architecture:
```bash
docker build -t ts-derp:latest .
```

### Test binary execution:
```bash
docker run --rm ts-derp:latest --version
```

### Build multi-architecture (`linux/amd64` and `linux/arm64`):
```bash
docker buildx build --platform linux/amd64,linux/arm64 -t ts-derp:latest .
```

---

## Running the DERP Server

### Docker Run

```bash
docker run -d \
  --name ts-derp \
  --restart unless-stopped \
  -p 443:443/tcp \
  -p 80:80/tcp \
  -p 3478:3478/udp \
  -v /opt/derp/certs:/certs \
  ts-derp:latest \
  --hostname=derp.example.com \
  --certdir=/certs \
  --certmode=letsencrypt \
  --acme-email=admin@example.com \
  --stun=true
```

### Docker Compose

Adjust [compose.yaml](file:///home/pants/Projects/container_projects/ts-derp/compose.yaml) to configure your hostname and certificate options:

```bash
docker compose up -d
```

Check the logs to verify ACME certificate acquisition:

```bash
docker compose logs -f derper
```

---

## Tailnet Configuration

Add your custom DERP node to your Tailscale ACL / DERP map in the Tailscale admin console under **Access Controls**:

```json
{
  "derpMap": {
    "Regions": {
      "900": {
        "RegionID": 900,
        "RegionCode": "custom-derp",
        "RegionName": "Custom Self-Hosted DERP",
        "Nodes": [
          {
            "Name": "900a",
            "RegionID": 900,
            "HostName": "derp.example.com",
            "DERPPort": 443,
            "STUNPort": 3478
          }
        ]
      }
    }
  }
}
```

Since the DERP server uses a valid Let's Encrypt certificate obtained via the built-in ACME service, Tailscale clients will automatically verify and trust the connection over port 443 without requiring custom root certificates or manual certificate fingerprint pinning.
