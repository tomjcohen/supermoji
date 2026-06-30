# supermoji

A command-line tool that turns emoji into GIFs — animated, cross-fading, or static — rendered at full quality from Apple Color Emoji. Built with **Slack custom emoji** in mind: a static GIF and an animated GIF render at the same size, unlike mixing a native unicode emoji with a custom one.

## Usage

```bash
# Cycle through emoji as an animated GIF
supermoji 😀😃😄😁😆

# Cross-fade between two emoji and back, as a looping GIF
supermoji fade ⚪ 🔵 -o pulsing.gif

# A single emoji as a static GIF (same size and quality as a fade)
supermoji still 🔴 -o red.gif
```

`fade` and `still` share one renderer, so a still and a fade endpoint of the same emoji at the same size are pixel-for-pixel identical. That lets you build progress rows or traffic lights where the active step animates and the rest are stills — all the same size in Slack.

### Subcommands

- **`animate`** *(default)* — cycle through emoji and/or image files as GIF frames; a single input produces a static GIF. Runs by default, so `supermoji 😀😃😄` needs no subcommand name.
- **`fade <A> <B>`** — cross-fade between exactly two emoji and back, as a seamless looping GIF.
- **`still <A>`** — render one emoji as a static GIF.

### Options

`animate` (default):

| Flag | Default | Description |
|------|---------|-------------|
| `--size` | 256 | Output dimensions in pixels (square) |
| `--delay` | 500 | Frame delay in milliseconds |
| `-o, --output` | output.gif | Output file path |

`fade`:

| Flag | Default | Description |
|------|---------|-------------|
| `--curve` | ease-in-out | Easing: `linear`, `ease-in`, `ease-out`, `ease-in-out` |
| `--fps` | 20 | Frames per second |
| `--duration` | 0.6 | One-way fade time, in seconds |
| `--size` | 128 | Output dimensions in pixels (square) |
| `--supersample` | 3 | Internal supersampling for smoother edges |
| `-o, --output` | output.gif | Output file path |

`still`:

| Flag | Default | Description |
|------|---------|-------------|
| `--size` | 128 | Output dimensions in pixels (square) |
| `--supersample` | 3 | Internal supersampling for smoother edges |
| `-o, --output` | output.gif | Output file path |

`fade` and `still` default to 128px (Slack's custom-emoji size) and warn if the GIF exceeds Slack's 128 KB limit.

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

Each emoji is rendered into a bitmap using CoreText and the system Apple Color Emoji font, then assembled into a GIF with ImageIO. `animate` swaps whole frames; `fade` cross-dissolves between two emoji by interpolating in premultiplied-alpha space, composited at a high working resolution and downscaled so edges and the transition stay smooth. Single inputs (and `still`) produce a static, non-animating GIF.

Compound emoji — skin tone variants, flags, ZWJ sequences like family emoji — are all handled correctly thanks to Swift's native grapheme cluster support.
