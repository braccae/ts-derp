# Tailscale DERP Server Container (`ts-derp`)

A minimal, secure containerization of Tailscale's DERP (Designated Encrypted Relay for Packets) relay server ([`tailscale.com/cmd/derper`](https://pkg.go.dev/tailscale.com/cmd/derper)).

## Features

- **Pure Minimal `scratch` Image**: Multi-stage build that compiles a statically linked Go binary (`CGO_ENABLED=0`) with symbol/DWARF stripping (`-s -w -extldflags '-static'`). The runtime image contains only the statically linked binary.
- **Multi-Architecture Support**: Built with `--platform=$BUILDPLATFORM` cross-compilation for native fast builds targeting both `linux/amd64` and `linux/arm64`.
- **Automated Dependency Updates via Dependabot**:
  - Pinned and tracked via [tools.go](file:///home/pants/Projects/container_projects/ts-derp/tools.go) and [go.mod](file:///home/pants/Projects/container_projects/ts-derp/go.mod).
  - Dependabot polls daily for new releases of `tailscale.com`.
  - Automatically raises PRs when new Tailscale versions are available.
- **CI/CD with GitHub Actions**: Multi-arch build pipeline that tests the container and pushes to GitHub Container Registry (`ghcr.io`).

---

## Repository Structure

- [Dockerfile](file:///home/pants/Projects/container_projects/ts-derp/Dockerfile): Multi-stage build compiling static `derper` and packaging into `scratch`.
- [tools.go](file:///home/pants/Projects/container_projects/ts-derp/tools.go): Declares `tailscale.com/cmd/derper` as a tool dependency to ensure `go.mod` retains the dependency.
- [go.mod](file:///home/pants/Projects/container_projects/ts-derp/go.mod) & [go.sum](file:///home/pants/Projects/container_projects/ts-derp/go.sum): Tracks the exact version of Tailscale.
- [.github/dependabot.yml](file:///home/pants/Projects/container_projects/ts-derp/.github/dependabot.yml): Configures daily Go module updates and weekly Docker/Actions updates.
- [.github/workflows/build.yml](file:///home/pants/Projects/container_projects/ts-derp/.github/workflows/build.yml): GitHub Actions workflow for build, test, and container registry publishing.
- [compose.yaml](file:///home/pants/Projects/container_projects/ts-derp/compose.yaml): Example Docker Compose configuration.

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

DERP requires:
- TCP port `443` (DERP HTTPS traffic)
- TCP port `80` (Let's Encrypt HTTP-01 challenge, if using `--certmode=letsencrypt`)
- UDP port `3478` (STUN server)
- A domain name pointing to the public IP of your server

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
  --stun=true
```

### Docker Compose

Adjust [compose.yaml](file:///home/pants/Projects/container_projects/ts-derp/compose.yaml) to configure your hostname and certificate options:

```bash
docker compose up -d
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
