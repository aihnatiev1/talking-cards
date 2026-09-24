# Store artwork

UA and EN screenshots use the same warm illustration-led layout. The Flutter app supplies real screen captures; Remotion adds localized headlines and the device frame.

## Capture the current app

Run from the repository root, on an iPhone simulator:

```sh
flutter drive --no-pub --driver=test_driver/integration_test.dart --target=integration_test/visual_refresh_test.dart --dart-define=AUDIT_LANG=uk -d SIMULATOR_ID
flutter drive --no-pub --driver=test_driver/integration_test.dart --target=integration_test/visual_refresh_test.dart --dart-define=AUDIT_LANG=en -d SIMULATOR_ID
```

The driver writes `public/screenshots/auto/refresh-{screen}-{locale}.png`. It seeds a local demonstration profile and freezes ambient motion for capture only. Dialogs over the content fail the capture. The captures and output are local files, excluded from Git.

## Render and review

From this directory:

```sh
npm ci
npm run check
npm run build:store
```

The renderer requires all 14 current captures and never falls back to older PNGs. It produces:

- `out/store-refresh/slot-{1..7}-{uk,en}.png`: 1290 × 2796 screenshot assets.
- `out/store-refresh/slot-1-{uk,en}-play.png`: alternative first headlines for a future controlled test.
- `out/store-refresh/overview.png`: both sets side by side.
- `out/store-refresh/index.html`: responsive gallery with full-size links.
- `out/store-refresh/manifest.json`: source filenames and modification timestamps.

Edit `src/storeShots.ts` for copy and screenshot selection, `src/StoreScreenshot.tsx` for layout. `StoreOverview` uses the exact same components, so it is suitable for checking all captions, crops and spacing at once. Captures and dependencies need to be present locally before rendering. The preview-video compositions also require the existing local music and feature captures.

## Release

These commands do not upload or publish anything. Review both languages before copying approved PNGs into `ios/fastlane/screenshots/`. The source scene uses a phone frame: prepare separate native iPad captures for an iPad-specific listing.

Search visibility and screenshot conversion are separate measurements. Test a first-slide treatment against the current published control in Product Page Optimization. Do not combine a metadata release and a screenshot experiment when trying to attribute the result. The edited metadata is a relevance hypothesis, not a verified high-volume keyword forecast.
