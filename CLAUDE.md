# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## State of the repo

Milestones **M0 (scaffold), M1 (rules core) and M2 (world: patience, beatings, resets, scars) and M3 (screens, text, save/load) are done**; see `docs/DESIGN.md` section 5 for the rest. The game is a stub that proves the pipeline. Do not invent answers to the design's open questions; ask the user.

## Commands

```bash
./test.sh    # native odin test of src/game, plus wasm type-check of both packages
./build.sh   # builds build/web (game.wasm, odin.js, index.html, assets)
./serve.sh   # http://localhost:8000 serving build/web
./shippit.sh # test, build, zip; uploads to itch.io only with --push (ask the user first)
```

Balance simulation (bot play over many seeds, see `docs/BALANCE.md`): `/home/yermom/ODIN/odin run tools/sim -collection:tggd=src -o:speed`

Single test: `/home/yermom/ODIN/odin test src/game -collection:tggd=src -define:ODIN_TEST_THREADS=1 -define:ODIN_TEST_NAMES=game.step_accumulates_time`

## Architecture

- `src/game` (package `game`): pure rules, no platform imports, tested natively. Time comes in as `dt_ms`; `step` is exact for any `dt_ms` (big step equals many small ones), which is what makes offline `catch_up` cheap (the sim runs in fixed 250 ms ticks). `world.odin` holds areas, beavers and the seeded generator; a beating is resolved in `beat_up` in `game.odin`. All tuning numbers are in `data.odin`.
- `src/web` (package `main`, `#+build js`): `web.odin` (frame loop, wall clock, save/load, input) and `screens.odin` (drawing, clickable buttons). Imports `fill_rect`, `blit` (tinted), `blit_raw`, `now_ms` and `storage_*` from `web/index.html`; the page calls the exported `on_click`.
- `src/game/save.odin` and `text.odin`: the save format with validation, and the trip-line picker.
- `web/index.html`: canvas shim. Loads sheets in the order of `Sheet` in `src/web/web.odin`; knocks black out of the Urizen sheet at load; tints the font at draw time. 640x360 canvas, everything drawn at 2x.
- `assets/`: `urizen.png` (12 px tiles, 1 px gap), `font.png` (DINOBYTE 6x8, 16x16 CP437), with licence records.

## Source of truth

The design lives in **this repo**: `docs/DESIGN.md` (decisions, the proposed vertical slice, milestones, open questions). Keep it current; the vault note only summarises and points here.

## The SPLORR!! knowledge base

Cross-game context and tech recipes live in the Obsidian vault at `/home/yermom/git/bok-of-splorr/splorr` (added to sessions as a working directory). Read these before doing anything:

- `Games/Beaver Hunters of SPLORR!!.md` – dated decision history and summary; points to `docs/DESIGN.md`.
- `Home.md` – index and **standing rules for sessions** (below).
- `Tech/Odin wasm recipe.md` – build/frame-loop/canvas recipe; see the "Turn Left at the Cow" and "Murder Hobo" variants.
- `Tech/Shipping to itch.io.md`, `Gotchas.md`, `Concepts/Metaphor design.md`.

Assets (Urizen tileset `Assets/urizen_onebit_tileset__v2d0.png`, DINOBYTE font `Assets/dbyte_1x.png`/`dbyte_2x.png`) are in the vault's `Assets/` and are CC0 / CC BY 4.0 respectively. Do not copy anything from `Assets/1bit-kingdom/` into this repo (redistribution forbidden).

## The design in brief (as decided Oct 15, 2026)

An idle/incremental "metaphor": hunt beavers for pelts; heavy double entendre **played completely straight** (the game never acknowledges the second meaning). Core loop: timed trips shown as a progress bar; pelts buy hired hands (specialities, steep ~1.15x cost curve); each area has a **hidden** patience meter per named beaver, which when exceeded makes the beavers gang up. Hands take the beating first (best hands first); with none left, a full reset occurs that leaves pelts/hands gone but keeps the world, lowers patience by a fixed amount, and leaves a per-beaver **scar**. Areas are endless, generated, remembered, and rotated between ("move on"). No win state, just a count. Ships on itch.io only.

## Intended stack and conventions

Not formally chosen, but the user's default is Odin compiled to `js_wasm32` (no emscripten, no WebGL – use a 2D canvas via a JS shim), toolchain at `/home/yermom/ODIN/odin`. Planned on the Murder Hobo core (`/home/yermom/git/murder-hobo-of-splorr`, shared framebuffer, 640x360 frame – verify at build time). Decided presentation: Urizen 12 px tiles at 2x, DINOBYTE 6x8 font drawn at 2x, tile scene with menus overlaid.

Established layout from sibling games (follow when scaffolding): pure rules package `src/game` with no platform imports plus thin `src/web` layer; native tests via `odin test src/game -collection:tggd=src -define:ODIN_TEST_THREADS=1`; `test.sh`, `build.sh`, and `shippit.sh` at the root.

## Rules specific to this project

- **Voice:** "yer" means "your" or "you're" only, never "you" ("You set the traps", "Erase yer save?"). Never write "your" or "you're" in player-facing strings. Grep both before committing text.
- Keep "of SPLORR!!" in the title; keep text suggestive, not explicit.
- Credit line required on the itch page and a credits screen: *DINOBYTE bitmap font by mby, https://mby.itch.io/dinobyte, CC BY 4.0*, plus Urizen (vurmux). Page needs the AI-use disclosure.
- Namespace any `localStorage` keys (all itch HTML5 games share one origin).
- Cap every retry loop; an infinite loop freezes the browser tab.
- **Never `git push` or run any publish/ship script unless the user explicitly says so.** `shippit.sh` should only upload with `--push`.
- Do not describe a game's deliberate design as a problem or "fix" it.
- No Steam planning (prices, wishlists, demos); this is not in the Steam pivot evaluation while itch-only.
