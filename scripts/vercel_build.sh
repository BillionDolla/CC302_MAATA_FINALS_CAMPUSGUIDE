#!/usr/bin/env bash
set -euo pipefail

if command -v flutter >/dev/null 2>&1; then
  FLUTTER_BIN="$(command -v flutter)"
else
  FLUTTER_VERSION="${FLUTTER_VERSION:-3.47.7}"
  SDK_ROOT="${TMPDIR:-/tmp}/campus-guide-flutter-${FLUTTER_VERSION}"
  FLUTTER_BIN="${SDK_ROOT}/flutter/bin/flutter"
  if [[ ! -x "${FLUTTER_BIN}" ]]; then
    mkdir -p "${SDK_ROOT}"
    curl --fail --location --silent --show-error \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
      | tar -xJ --strip-components=1 -C "${SDK_ROOT}"
  fi
fi

"${FLUTTER_BIN}" config --enable-web
"${FLUTTER_BIN}" pub get
"${FLUTTER_BIN}" build web --release
