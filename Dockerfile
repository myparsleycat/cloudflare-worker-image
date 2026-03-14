# ---- Builder Stage ----
# Use a Rust image based on Debian Bookworm to ensure GLIBC compatibility
FROM rust:1-slim-bookworm AS builder

# Set the working directory
WORKDIR /usr/src/photon-container

# Install build dependencies, including nasm and meson to build dav1d
RUN apt-get update && apt-get install -y \
    pkg-config \
    build-essential \
    ca-certificates \
    libssl-dev \
    git \
    nasm \
    meson \
    ninja-build && \
    rm -rf /var/lib/apt/lists/*

# Build and install dav1d 1.4.1 from source
RUN git clone -b 1.4.1 https://code.videolan.org/videolan/dav1d.git && \
    cd dav1d && \
    mkdir build && cd build && \
    meson setup .. --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --buildtype release && \
    ninja && \
    ninja install && \
    cd ../.. && rm -rf dav1d

# Copy the application source code
COPY ./photon-container/ .

# Build the application in release mode
RUN cargo build --release

# ---- Final Stage ----
# Use Debian Bookworm as it has a newer GLIBC version compatible with the builder
FROM debian:bookworm-slim

# Install runtime dependencies required to build and run dav1d, then cleanup
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates libssl3 git nasm meson ninja-build pkg-config build-essential && \
    git clone -b 1.4.1 https://code.videolan.org/videolan/dav1d.git && \
    cd dav1d && \
    mkdir build && cd build && \
    meson setup .. --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --buildtype release && \
    ninja && \
    ninja install && \
    cd ../.. && rm -rf dav1d && \
    apt-get purge -y git nasm meson ninja-build build-essential && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

# Copy the compiled binary from the builder stage
COPY --from=builder /usr/src/photon-container/target/release/photon-container /usr/local/bin/photon-container

# Expose the port the application runs on
EXPOSE 8000

# Set the command to run the application
CMD ["photon-container"]
