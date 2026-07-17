# note_approval

Vistar Note for Approval Portal

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Deploying to Cloudflare

The web build is served by Cloudflare Workers as an assets-only Worker
(`wrangler.jsonc`, no Worker script). `build.sh` installs the pinned Flutter
SDK and produces `build/web`.

| Cloudflare setting | Value        |
| ------------------ | ------------ |
| Build command      | `bash build.sh` |
| Deploy command     | `npx wrangler deploy` |
| Version preview    | `npx wrangler versions upload` |
| Root directory     | `/`          |

To deploy from a workstation instead: `npm install` once, then `npm run deploy`.

### Configuration

The API the portal talks to is baked in at build time. Override it by setting
`API_BASE_URL` as a build variable in the Cloudflare dashboard; `build.sh`
passes it through as a `--dart-define`. It is compiled into the JS bundle, so
it is public — never put a secret there.

### Why a deploy is visible immediately

Two things normally make a Flutter web app serve stale code after a deploy, and
both are switched off:

- **The service worker.** Builds use `--pwa-strategy=none`, so none is
  generated or registered. `web/index.html` also unregisters any worker left
  over from an earlier build, which would otherwise outlive the change.
- **Filename caching.** Flutter does not content-hash its output — every build
  emits the same `main.dart.js`, so a browser cannot tell a new bundle from the
  one it already cached. `web/_headers` sends `Cache-Control: no-cache`, which keeps the
  file in the browser cache but forces a revalidation against the edge before
  each reuse. Unchanged files come back as a ~300-byte `304`, so repeat loads
  stay fast while a deploy lands on the next request.

Users never need to hard-refresh or clear their cache.
