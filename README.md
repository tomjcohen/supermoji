# supermoji

A command-line tool that generates animated GIFs from emoji, rendered at full quality from Apple Color Emoji.

## Usage

```bash
# Animated GIF cycling through emoji
supermoji 😀😃😄😁😆

# Single emoji as a static GIF
supermoji 🎉 -o party.gif

# Custom size and speed
supermoji 🤙👍 --size 512 --delay 200 -o thumbs.gif
```

### Options

| Flag | Default | Description |
|------|---------|-------------|
| `--size` | 256 | Output dimensions in pixels (square) |
| `--delay` | 500 | Frame delay in milliseconds |
| `-o, --output` | output.gif | Output file path |

All flags are optional. Emoji are passed as a single positional argument.

## Install

Requires macOS 13+ and Swift 6.

```bash
git clone https://github.com/tomjcohen/supermoji.git
cd supermoji
swift build -c release
cp .build/release/supermoji /usr/local/bin/
```

## Releases

Download the latest `.dmg` from [Releases](https://github.com/tomjcohen/supermoji/releases). Open the DMG and drag Supermoji to your Applications folder.

To trigger a new release, add one of these labels to a PR before merging to main:

| Label | Effect |
|-------|--------|
| `release-patch` | Bump `0.0.x` |
| `release-minor` | Bump `0.x.0` |
| `release-major` | Bump `x.0.0` |

## How it works

Each emoji character is rendered individually into a bitmap using CoreText and the system Apple Color Emoji font, then assembled into an animated GIF using ImageIO. Single emoji produce a static (non-animating) GIF.

Compound emoji — skin tone variants, flags, ZWJ sequences like family emoji — are all handled correctly thanks to Swift's native grapheme cluster support.
