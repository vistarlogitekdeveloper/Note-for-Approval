#!/usr/bin/env bash
# Builds the Flutter web bundle. Cloudflare's build image ships no Flutter or
# Dart toolchain, so we fetch one here. The version is pinned so a deploy never
# silently moves onto a new Flutter release.
set -euo pipefail

FLUTTER_VERSION="3.44.4"
FLUTTER_HOME="${HOME}/flutter"
FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"

if [ ! -x "${FLUTTER_HOME}/bin/flutter" ]; then
  echo "==> Installing Flutter ${FLUTTER_VERSION}"
  curl -fsSL --retry 3 "${FLUTTER_URL}" -o /tmp/flutter.tar.xz
  tar -xf /tmp/flutter.tar.xz -C "${HOME}"
  rm -f /tmp/flutter.tar.xz
fi

export PATH="${FLUTTER_HOME}/bin:${PATH}"

# The SDK ships as a git checkout. CI extracts it as a different owner than the
# one git expects, which makes git refuse to read the repo and flutter abort.
git config --global --add safe.directory "${FLUTTER_HOME}" || true

flutter --version
flutter pub get

# --pwa-strategy=none   no service worker is generated or registered, so a
#                       deploy can never be masked by an offline cache.
# --no-web-resources-cdn  self-host CanvasKit instead of pulling it from
#                       gstatic.com, keeping every asset on our own origin and
#                       under the cache rules in web/_headers.
flutter build web \
  --release \
  --pwa-strategy=none \
  --no-web-resources-cdn \
  --dart-define=API_BASE_URL="${API_BASE_URL:-https://vistar-crm.onrender.com/api/v1/note-for-approval}"

echo "==> Built build/web"
