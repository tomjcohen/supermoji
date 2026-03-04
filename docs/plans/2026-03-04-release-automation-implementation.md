# Release Automation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Automate GitHub Releases with a downloadable DMG when PRs merge to main with a release label.

**Architecture:** A GitHub Actions workflow triggers on push to main, detects release labels on the merged PR, bumps a VERSION file, builds a DMG via xcodebuild, and creates a GitHub Release with the DMG attached.

**Tech Stack:** GitHub Actions, xcodegen, xcodebuild, hdiutil, gh CLI

---

### Task 1: Create VERSION file and repo labels

**Files:**
- Create: `VERSION`

**Step 1: Create the VERSION file**

```
1.0.0
```

No trailing newline — just `1.0.0`.

**Step 2: Create the three GitHub labels**

Run:
```bash
gh label create release-patch --description "Bump patch version on merge" --color "0E8A16"
gh label create release-minor --description "Bump minor version on merge" --color "1D76DB"
gh label create release-major --description "Bump major version on merge" --color "D93F0B"
```

Expected: Three labels created on the repo.

**Step 3: Commit**

```bash
git add VERSION
git commit -m "chore: add VERSION file for release automation

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Create the release workflow

**Files:**
- Create: `.github/workflows/release.yml`

**Step 1: Create the workflow file**

```yaml
name: Release

on:
  push:
    branches: [main]

permissions:
  contents: write

jobs:
  check-release:
    runs-on: ubuntu-latest
    outputs:
      should_release: ${{ steps.check.outputs.should_release }}
      bump: ${{ steps.check.outputs.bump }}
      pr_title: ${{ steps.check.outputs.pr_title }}
    steps:
      - uses: actions/checkout@v4

      - name: Check merged PR for release label
        id: check
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          # Find the PR that was merged for this push
          PR=$(gh pr list --state merged --search "${{ github.sha }}" --json number,labels,title --limit 1)

          if [ "$PR" = "[]" ]; then
            echo "should_release=false" >> "$GITHUB_OUTPUT"
            exit 0
          fi

          LABELS=$(echo "$PR" | jq -r '.[0].labels[].name' 2>/dev/null || echo "")
          TITLE=$(echo "$PR" | jq -r '.[0].title' 2>/dev/null || echo "")

          if echo "$LABELS" | grep -q "release-major"; then
            BUMP="major"
          elif echo "$LABELS" | grep -q "release-minor"; then
            BUMP="minor"
          elif echo "$LABELS" | grep -q "release-patch"; then
            BUMP="patch"
          else
            echo "should_release=false" >> "$GITHUB_OUTPUT"
            exit 0
          fi

          echo "should_release=true" >> "$GITHUB_OUTPUT"
          echo "bump=$BUMP" >> "$GITHUB_OUTPUT"
          echo "pr_title=$TITLE" >> "$GITHUB_OUTPUT"

  release:
    needs: check-release
    if: needs.check-release.outputs.should_release == 'true'
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
        with:
          token: ${{ github.token }}

      - name: Bump version
        id: version
        run: |
          CURRENT=$(cat VERSION)
          IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"

          case "${{ needs.check-release.outputs.bump }}" in
            major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
            minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
            patch) PATCH=$((PATCH + 1)) ;;
          esac

          NEW="${MAJOR}.${MINOR}.${PATCH}"
          echo -n "$NEW" > VERSION
          echo "version=$NEW" >> "$GITHUB_OUTPUT"
          echo "tag=v$NEW" >> "$GITHUB_OUTPUT"

      - name: Install xcodegen
        run: brew install xcodegen

      - name: Build app
        run: |
          xcodegen generate
          xcodebuild -project Supermoji.xcodeproj \
            -scheme SupermojiApp \
            -configuration Release \
            -derivedDataPath .build/release-app \
            build

      - name: Sign and package DMG
        id: dmg
        run: |
          APP_PATH=".build/release-app/Build/Products/Release/Supermoji.app"
          DMG_NAME="Supermoji-${{ steps.version.outputs.tag }}.dmg"

          codesign --deep --force --sign "-" --options runtime "$APP_PATH"

          hdiutil create -volname "Supermoji" \
            -srcfolder "$APP_PATH" \
            -ov -format UDZO \
            "$DMG_NAME"

          echo "dmg_name=$DMG_NAME" >> "$GITHUB_OUTPUT"

      - name: Commit version bump and tag
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add VERSION
          git commit -m "chore: bump version to ${{ steps.version.outputs.version }}"
          git tag "${{ steps.version.outputs.tag }}"
          git push origin main --tags

      - name: Create GitHub Release
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          gh release create "${{ steps.version.outputs.tag }}" \
            "${{ steps.dmg.outputs.dmg_name }}" \
            --title "${{ steps.version.outputs.tag }}" \
            --notes "${{ needs.check-release.outputs.pr_title }}"
```

**Step 2: Verify YAML is valid**

Run: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/release.yml'))"`
Expected: No errors.

If `pyyaml` isn't installed, `cat .github/workflows/release.yml | head -5` to sanity check the structure.

**Step 3: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "feat: add release workflow triggered by PR labels

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Update documentation

**Files:**
- Modify: `README.md`
- Modify: `CONTRIBUTING.md`
- Modify: `CLAUDE.md`

**Step 1: Add releases section to README.md**

After the "Install" section, add:

```markdown
## Releases

Download the latest `.dmg` from [Releases](https://github.com/tomjcohen/supermoji/releases). Open the DMG and drag Supermoji to your Applications folder.

To trigger a new release, add one of these labels to a PR before merging to main:

| Label | Effect |
|-------|--------|
| `release-patch` | Bump `0.0.x` |
| `release-minor` | Bump `0.x.0` |
| `release-major` | Bump `x.0.0` |
```

**Step 2: Add release info to CONTRIBUTING.md**

After the "Pull Requests" section, add:

```markdown
## Releases

Releases are automated. To trigger a release, add a `release-patch`, `release-minor`, or `release-major` label to your PR before merging to main. The workflow will bump the version, build a DMG, and create a GitHub Release.
```

**Step 3: Add release workflow note to CLAUDE.md**

After the "Key Conventions" section, add:

```markdown
## Releases

- Version tracked in `VERSION` file at repo root (semver, e.g. `1.0.0`)
- Release workflow: `.github/workflows/release.yml`
- Triggered by `release-patch`, `release-minor`, or `release-major` labels on merged PRs
- Builds DMG via xcodegen + xcodebuild, creates GitHub Release with DMG attached
```

**Step 4: Commit**

```bash
git add README.md CONTRIBUTING.md CLAUDE.md
git commit -m "docs: add release workflow documentation

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Push and verify

**Step 1: Push the branch**

```bash
git push
```

**Step 2: Verify labels exist**

Run: `gh label list | grep release`
Expected: Three labels listed.

**Step 3: Verify workflow file is valid**

Run: `gh workflow list`
Expected: Release workflow appears (after push to origin).
