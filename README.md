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

### Usage analytics (event tracker)

`lib/core/telemetry/telemetry.dart`, using the in-house `vistar_event_tracker`
SDK (vendored in `packages/`, see its `VENDORED.md`). Read in the Platform
Console under Analytics > Event tracker; register the app there (Settings >
Event tracker) as `nfa_app` to get its write key.

**Off unless the build gets both `ET_APP_ID` and `ET_WRITE_KEY`.** Without
them nothing is initialised, the telemetry code is tree-shaken out of the web
build and the portal behaves exactly as before.

- **Live web app.** To switch analytics on, add two build variables to the
  `note-for-approval` Worker (Settings > Build > Variables and secrets):
  `ET_APP_ID` = `nfa_app` and `ET_WRITE_KEY` (encrypted; paste the values with
  no leading space or newline), then redeploy. `build.sh` passes them to
  `flutter build web` only when both are set and logs
  `Usage analytics on, as nfa_app` (or `off`). If the dashboard's build
  command is ever replaced by an inline one, append
  `--dart-define=ET_APP_ID=$ET_APP_ID --dart-define=ET_WRITE_KEY=$ET_WRITE_KEY`
  to its `flutter build web` instead.
- **APK / other builds.** Add
  `--dart-define=ET_APP_ID=nfa_app --dart-define=ET_WRITE_KEY=wk_...`.

Events go to the host of `API_BASE_URL` (a UAT build reports to UAT);
`ET_BASE_URL` overrides it.

Sent: screen views by route pattern (`/notes/:id/edit`), sign-in / sign-out
(the user as `nfa:<user id>` with their role only), named actions from
successful API writes (`note_created`, `note_submitted`, `note_approved`,
`note_rejected`, `note_returned`, ... see `_actions`), failed API calls
(5xx / no connection: endpoint pattern, method, status) and client errors
(error type only). Never sent: request or response bodies, error messages,
note titles, bodies or numbers, amounts, remarks, attachment names, approver
or user names, emails. Nothing is awaited by a screen, a note, an approval, a
sign-in or a sign-out; start-up waits at most 2 s; the event queue is capped at
200 in shared preferences.

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
