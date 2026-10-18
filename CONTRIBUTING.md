# Contributing

Thanks for helping make Kumquat better!

## Getting started

```bash
git clone https://github.com/iandifilippo/Kumquat.git
cd Kumquat
swift test                     # conversion tests
UNIVERSAL=0 scripts/build-app.sh && open build/Kumquat.app
```

## Where things live

- **New format or tool?** Add it to `OutputFormat` or `ToolID`, list it in `ActionCatalog`, implement it in `Engine`, and add a test in `Tests/KumquatCoreTests`. Give it a title, symbol and description in `Localization.swift`, plus a Spanish translation.
- **UI text?** Wrap it in `L("…")` and add a line to every table in `Sources/Kumquat/Localization/` (Spanish in `Translations.swift`, the others in `Translations+<code>.swift`). Run `scripts/check-translations.py`: it lists missing or repeated keys.
- **Needs an external tool?** Add it to `Engines.swift` (detected, never downloaded), only offer the format when it's installed, and add a test to `EngineIntegrationTests` that skips when the tool is missing.
- **README images?** `.build/debug/Kumquat --render-screenshots docs/assets` redraws them from the real views. `--render-ui <dir> <image>` renders every window and `--render-rings <dir>` the ring in every language, to check layouts.
- **Website?** It's `docs/index.html`, served by GitHub Pages.

## Pull requests

- Keep each PR to one change and describe how you tested it.
- `swift test` and `scripts/check-translations.py` must pass (CI runs both).
- Match the surrounding style: small types, plain names, short comments that explain *why*.
