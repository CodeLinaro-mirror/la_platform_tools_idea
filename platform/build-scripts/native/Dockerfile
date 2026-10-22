FROM ubuntu:20.04

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
    make \
    cmake \
    xz-utils \
    zip unzip \
    binutils \
    clang \
    musl musl-tools \
    curl \
    pkg-config \
    libssl-dev \
    mingw-w64 \
    gcc-aarch64-linux-gnu \
    libc6-dev-arm64-cross \
    file \
    && rm -rf /var/lib/apt/lists/*

# Ubuntu's mingw-w64 packages only support i686 and x86-64 (GCC lacks Windows ARM64 support).
# Install llvm-mingw to provide aarch64-w64-mingw32-* for Rust's aarch64-pc-windows-gnullvm target.
# Append to PATH so Ubuntu's /usr/bin/x86_64-w64-mingw32-gcc remains first for x86_64-pc-windows-gnu.
RUN curl -fSL \
    --connect-timeout 120 \
    --max-time 300 \
    --retry 5 \
    --retry-delay 5 \
    --retry-connrefused \
    "https://github.com/mstorsjo/llvm-mingw/releases/download/20250402/llvm-mingw-20250402-ucrt-ubuntu-20.04-x86_64.tar.xz" \
    -o /tmp/llvm-mingw.tar.xz \
 && mkdir -p /opt/llvm-mingw \
 && tar -xJf /tmp/llvm-mingw.tar.xz -C /opt/llvm-mingw --strip-components=1 \
 && rm /tmp/llvm-mingw.tar.xz
ENV PATH="${PATH}:/opt/llvm-mingw/bin"

RUN useradd -ms /bin/bash builder
USER builder

RUN curl -fSL \
    --connect-timeout 120 \
    --max-time 300 \
    --retry 5 \
    --retry-delay 5 \
    --retry-connrefused \
    "https://musl.libc.org/releases/musl-1.2.6.tar.gz" \
    -o /home/builder/musl-1.2.6.tar.gz \
 && chown builder:builder /home/builder/musl-1.2.6.tar.gz
RUN chmod 644 /home/builder/musl-1.2.6.tar.gz

# Setup Rust for offline build
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y -v --default-toolchain stable --default-host x86_64-unknown-linux-gnu --profile minimal; \
    . "$HOME/.cargo/env"; \
    rustup target add x86_64-unknown-linux-musl; \
    rustup target add aarch64-unknown-linux-musl; \
    rustup target add aarch64-unknown-linux-gnu; \
    rustup target add x86_64-pc-windows-gnu; \
    rustup target add aarch64-pc-windows-gnullvm; \
    cargo install --locked cargo-about; \
    rustup show;


# Pre-fetch dependencies for Rust projects

# create empty project
RUN mkdir -p /home/builder/prefetch/src && echo "fn main() {}" > /home/builder/prefetch/src/main.rs && echo "fn main() {}" > /home/builder/prefetch/build.rs
WORKDIR /home/builder/prefetch

# fetch dependencies for XPlatLauncher
COPY cargo/XPlatLauncher/Cargo.toml cargo/XPlatLauncher/Cargo.lock /home/builder/prefetch/
# 0.8.4 is max version that understands "no-clearly-defined" in about.toml
RUN . "$HOME/.cargo/env"; cargo fetch ; cargo install --locked --force --version 0.8.4 cargo-about

# fetch dependencies for restarter
COPY cargo/restarter/Cargo.toml cargo/restarter/Cargo.lock /home/builder/prefetch/
RUN . "$HOME/.cargo/env"; cargo fetch

# some crates (fnv-1.0.7) have busted permissions. Make cargo cache readable for everyone
RUN chmod -R a+r "$HOME/.cargo"

WORKDIR /home/builder