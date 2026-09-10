# syntax=docker/dockerfile:1

# Stage 1: Build statically linked binary using host platform Go compiler
FROM --platform=$BUILDPLATFORM golang:alpine AS builder

ARG TARGETOS
ARG TARGETARCH

WORKDIR /src

# Copy module definitions and pre-download dependencies
COPY go.mod go.sum tools.go ./
RUN go mod download

# Compile statically linked derper binary for the target architecture
RUN CGO_ENABLED=0 GOOS=${TARGETOS:-linux} GOARCH=${TARGETARCH:-amd64} go build \
    -trimpath \
    -ldflags="-s -w -extldflags '-static'" \
    -o /bin/derper \
    tailscale.com/cmd/derper

# Stage 2: Final minimal scratch container containing only the binary
FROM scratch

COPY --from=builder /bin/derper /derper

EXPOSE 443/tcp 80/tcp 3478/udp

ENTRYPOINT ["/derper"]
