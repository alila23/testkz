# Stage 1: Build web interface
FROM node:22-bookworm-slim AS web-builder

WORKDIR /src/panel/web

COPY panel/web/package.json panel/web/package-lock.json ./
RUN npm ci

COPY panel/web/ ./
RUN npm run build


# Stage 2: Build Rust binaries
FROM rust:1-bookworm AS rust-builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    musl-tools \
    build-essential \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

RUN rustup target add x86_64-unknown-linux-musl

WORKDIR /src

COPY . .

# Embed the actual web application before compiling the panel.
COPY --from=web-builder /src/panel/web/dist ./panel/web/dist

RUN cargo build \
    --release \
    --locked \
    --target x86_64-unknown-linux-musl \
    -p kariz \
    -p kariz-panel


# Stage 3: Runtime
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p \
    /etc/kariz \
    /etc/kariz-panel \
    /var/lib/kariz-panel

COPY --from=rust-builder \
    /src/target/x86_64-unknown-linux-musl/release/kariz \
    /usr/local/bin/kariz

COPY --from=rust-builder \
    /src/target/x86_64-unknown-linux-musl/release/kariz-panel \
    /usr/local/bin/kariz-panel

RUN chmod 755 /usr/local/bin/kariz /usr/local/bin/kariz-panel

ENV KARIZ_MANAGER=/bin/true
ENV RUST_LOG=info

WORKDIR /

ENTRYPOINT ["/usr/local/bin/kariz-panel"]
CMD ["--help"]
