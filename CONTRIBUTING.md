# Contributing to supermoji

Thanks for your interest in contributing!

## Getting Started

1. Fork and clone the repo
2. `swift build` to compile
3. `swift test` to run the test suite

## Before You Start

Please **open an issue first** to discuss any changes you'd like to make. This helps avoid duplicate effort and ensures your contribution aligns with the project direction.

## Pull Requests

- Keep PRs focused on a single change
- Use [conventional commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `refactor:`, etc.)
- Ensure `swift build` and `swift test` pass before submitting

## Releases

Releases are automated. To trigger a release, add a `release-patch`, `release-minor`, or `release-major` label to your PR before merging to main. The workflow will bump the version, build a DMG, and create a GitHub Release.

## Requirements

- macOS (AppKit is required for colour emoji rendering)
- Swift 6+
