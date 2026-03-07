#!/usr/bin/env bash
# Build zvec C++ library from source.
# Usage: script/build_zvec.sh [install_prefix]
#
# Sets ZVEC_DIR to the source directory for use with extconf.rb.
# If install_prefix is given, also runs `make install`.

set -euo pipefail

ZVEC_SRC="${ZVEC_SRC:-/tmp/zvec}"
INSTALL_PREFIX="${1:-}"

# Clone if not already present
if [ ! -d "$ZVEC_SRC" ]; then
  echo "==> Cloning zvec..."
  git clone --depth 1 https://github.com/alibaba/zvec "$ZVEC_SRC"
fi

# Build
echo "==> Building zvec..."
cd "$ZVEC_SRC"
mkdir -p build
cd build
cmake .. \
  -DCMAKE_BUILD_TYPE=Release \
  ${INSTALL_PREFIX:+-DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX}
make -j"$(nproc 2>/dev/null || sysctl -n hw.ncpu)"

if [ -n "$INSTALL_PREFIX" ]; then
  echo "==> Installing to $INSTALL_PREFIX..."
  make install
fi

echo "==> Done. Set ZVEC_DIR=$ZVEC_SRC when compiling the gem."
echo "    Example: ZVEC_DIR=$ZVEC_SRC gem install zvec"
