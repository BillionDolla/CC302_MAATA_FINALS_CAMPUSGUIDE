#!/usr/bin/env bash
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.47.7}"
SDK_ROOT="${TMPDIR:-/tmp}/campus-guide-flutter-${FLUTTER_VERSION}"
FLUTTER_DIR="${SDK_ROOT}/flutter"

if command -v flutter >/dev/null 2>&1; then
  FLUTTER_BIN="$(command -v flutter)"
else
  FLUTTER_BIN="${FLUTTER_DIR}/bin/flutter"

  if [[ ! -x "${FLUTTER_BIN}" ]]; then
    mkdir -p "${FLUTTER_DIR}"

    curl --fail --location --silent --show-error \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
      -o "${SDK_ROOT}/flutter.tar.xz"

    tar -xJf "${SDK_ROOT}/flutter.tar.xz" \
      --strip-components=1 -C "${FLUTTER_DIR}"

    rm -f "${SDK_ROOT}/flutter.tar.xz"
  fi
fi

if [[ ! -x "${FLUTTER_BIN}" ]]; then
  echo "ERROR: Flutter executable not found: ${FLUTTER_BIN}"
  exit 1
fi

if [[ -d "${FLUTTER_DIR}/.git" ]]; then
  git config --global --add safe.directory "${FLUTTER_DIR}"
fi

"${FLUTTER_BIN}" --version
"${FLUTTER_BIN}" config --enable-web
"${FLUTTER_BIN}" pub get
"${FLUTTER_BIN}" build web --release