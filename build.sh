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

DART_DEFINES=(--dart-define=API_BASE_URL="${API_BASE_URL:-https://api.vistarlogitek.com/api/v1/note-for-approval}")

# Usage analytics (lib/core/telemetry/telemetry.dart). On only when BOTH build
# variables are set - ET_APP_ID (nfa_app) and ET_WRITE_KEY (encrypted) - under
# Settings -> Build -> Variables and secrets. Either missing: no define is
# passed and the app sends nothing, exactly as before. ET_BASE_URL is optional
# (events go to the API host by default). Never echo the key.
if [ -n "${ET_APP_ID:-}" ] && [ -n "${ET_WRITE_KEY:-}" ]; then
  DART_DEFINES+=(--dart-define=ET_APP_ID="${ET_APP_ID}" --dart-define=ET_WRITE_KEY="${ET_WRITE_KEY}")
  if [ -n "${ET_BASE_URL:-}" ]; then
    DART_DEFINES+=(--dart-define=ET_BASE_URL="${ET_BASE_URL}")
  fi
  echo "==> Usage analytics on, as ${ET_APP_ID}"
else
  echo "==> Usage analytics off (ET_APP_ID / ET_WRITE_KEY not set)"
fi

# --pwa-strategy=none   no service worker is generated or registered, so a
#                       deploy can never be masked by an offline cache.
# --no-web-resources-cdn  self-host CanvasKit instead of pulling it from
#                       gstatic.com, keeping every asset on our own origin and
#                       under the cache rules in web/_headers.
flutter build web \
  --release \
  --pwa-strategy=none \
  --no-web-resources-cdn \
  "${DART_DEFINES[@]}"

echo "==> Built build/web"
