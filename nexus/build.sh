#!/bin/sh
# Build PortSentry 2.0.7 on Alpine Linux (musl libc, OpenRC, no systemd)
# Requires: cmake make gcc musl-dev linux-headers libpcap-dev
# See ALPINE-PATCHES.md for full patch notes

set -e

cd "$(dirname "$0")/.."

echo "=== PortSentry Alpine Build ==="
cmake -B release \
  -D CMAKE_BUILD_TYPE=Release \
  -D CMAKE_INSTALL_PREFIX=/ \
  -D USE_SYSTEMD=OFF \
  -D USE_PCAP=OFF

cmake --build release

echo ""
echo "=== Build result: $? ==="
ls -lh release/portsentry 2>/dev/null && echo "Binary ready." || echo "Build failed — check output above."
