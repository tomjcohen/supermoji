# Release Automation — Design

## Goal

Automate GitHub Releases with a downloadable DMG when PRs merge to main with a release label.

## Trigger

A GitHub Actions workflow triggers on `push` to `main`. It finds the merged PR for that commit and checks for one of three labels:

- `release-patch` — bumps `0.0.x`
- `release-minor` — bumps `0.x.0`
- `release-major` — bumps `x.0.0`

If no release label is present, the workflow exits early. If multiple labels are present, the highest wins (major > minor > patch).

## Versioning

Current version stored in a `VERSION` file at the repo root (e.g. `1.0.0`). The workflow reads this, bumps the appropriate component, writes it back, commits, and pushes.

## Build & Package

On a `macos-latest` runner:

1. Install xcodegen via Homebrew
2. `xcodegen generate`
3. `xcodebuild -project Supermoji.xcodeproj -scheme SupermojiApp -configuration Release build`
4. Ad-hoc code sign (`codesign --sign "-"`) — no Developer ID for now
5. Package into `Supermoji-vX.Y.Z.dmg` via `hdiutil create`

## Release

1. Commit the version bump and push to main
2. Tag the commit as `vX.Y.Z`
3. Create a GitHub Release via `gh release create` with the DMG attached
4. Release title: `vX.Y.Z`; body: auto-generated from the merged PR title

## Future: Notarisation

When a Developer ID certificate is available, add these secrets:

- `DEVELOPER_ID_CERTIFICATE_P12` — base64-encoded .p12
- `DEVELOPER_ID_CERTIFICATE_PASSWORD` — .p12 password
- `NOTARYTOOL_APPLE_ID` / `NOTARYTOOL_PASSWORD` / `NOTARYTOOL_TEAM_ID`

The workflow would then import the cert into a temporary keychain, sign with the real identity, and notarise via `xcrun notarytool submit --wait`.

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Trigger | PR labels on merge | Visible, intentional, no manual steps |
| Version storage | `VERSION` file | Simple, no plist/YAML parsing |
| Signing | Ad-hoc for now | No Developer ID cert available yet |
| Runner | `macos-latest` | Required for xcodebuild |
| Version bump commit | Automated push to main | Keeps VERSION file in sync |
