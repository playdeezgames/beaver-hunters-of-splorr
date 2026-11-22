#!/usr/bin/env bash
# Prepares the itch.io html build: tests, a web build, a zip. Pushes ONLY with --push, and only when the
# user has said to ship (one ship a day, booked through Coxswain). Never commits, never deletes anything
# but its own zip. Usage: tools/ship.sh [--push]
# Page: https://thegrumpygamedev.itch.io/beaver-hunters-of-splorr (live; channel html, do not rename).
set -euo pipefail
cd "$(dirname "$0")/.."
TARGET="${ITCH_TARGET:-thegrumpygamedev/beaver-hunters-of-splorr:html}"
ZIP="build/beaver-hunters-of-splorr-html5.zip"

./test.sh
rm -rf build/web
./build.sh
rm -f "$ZIP"
(cd build/web && zip -q -9 -r "../$(basename "$ZIP")" .)
echo "zip: $ZIP ($(du -h "$ZIP" | cut -f1)); wasm $(du -h build/web/game.wasm | cut -f1)"
unzip -l "$ZIP" | tail -12

if [ "${1:-}" = "--push" ]; then
	if [ -n "$(git status --porcelain)" ]; then
		echo "note: the working tree has uncommitted changes; what is pushed is the working tree, not a commit"
	fi
	butler push "$ZIP" "$TARGET"
	echo "pushed to $TARGET. It goes live after itch.io processes it; check: butler status $TARGET"
else
	echo "not pushed (run tools/ship.sh --push when you want it live; the target is $TARGET)"
fi
