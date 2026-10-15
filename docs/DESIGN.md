# Beaver Hunters of SPLORR!! – Design

Status: **planning**. This file is the source of truth for the design. The vault note
(`bok-of-splorr/splorr/Games/Beaver Hunters of SPLORR!!.md`) keeps a summary and a pointer here.
Items marked **PROPOSED** are drafts for the user to accept, change or reject; nothing marked
PROPOSED is decided.

## 1. Premise (decided)

A metaphor: hunt beavers, collect pelts. Heavy double entendre, **played completely straight**
(the game never acknowledges the second meaning). Idle/incremental. No win state, just a count.
Voice is "yer" throughout. Ships on itch.io only. Title keeps "of SPLORR!!". Suggestive, not explicit.

## 2. Mechanics (decided)

| Element | Decision |
| --- | --- |
| Hunt | A **timed trip**. Hunter goes out, time passes, returns with pelts. Shown as a plain progress bar; scene stays still. |
| Pelts | Currency. Main sink is **hired hands** who make trips on their own. |
| Hands | Have **specialities** (e.g. quiet = drain less patience, strong = haul more). Steep cost curve, ~1.15x per hand of a kind (tune in play). |
| Beavers | **Named individuals** with a **temperament**; they remember yer. |
| Patience | **Hidden**, builds per area from trips/pelts taken. Recovers while yer are elsewhere. Hands drain it too (assumed; confirm). |
| Beating | When an area's beavers are fed up they gang up. **Hands take it first, best first.** With none left, a **full reset**. |
| Reset | Pelts and hands go. **World is kept.** Every area's patience drops by a fixed amount (not cleared). Leaves a **scar** on the beaver(s) responsible. |
| Scars | Per-beaver. Later runs, that beaver leaves yer alone or comes after yer first, depending on its temperament. |
| Areas | **Endless, generated, remembered.** "Move on" picks/creates another area; yer pick one per trip. Rotating is the skill. |
| Text | A deadpan line from a list at the end of each trip. The double entendre lives here. The user writes the jokes. |

## 3. Presentation (decided)

- 640x360 frame, Urizen 12 px tiles at 2x (≈26x15 tiles), DINOBYTE 6x8 font at 2x.
- A tile scene of the current area (hunter, hands, beavers) with menus overlaid in DINOBYTE.
- Title screen: small hunting scene behind the title. Credits screen reachable from it:
  Urizen (vurmux, CC0) and *DINOBYTE bitmap font by mby, https://mby.itch.io/dinobyte, CC BY 4.0*.
- Stack: Odin to `js_wasm32`, 2D canvas shim, no WebGL. Pure rules package + thin web layer
  (see vault `Tech/Odin wasm recipe.md`, Turn Left at the Cow variant).

## 4. Vertical slice (PROPOSED)

Goal: the **whole loop, thin**, playable end to end in a browser and shippable to itch.io: hunt →
earn → hire → overreach → get beaten → reset with a scar → feel the scar next run. Anything that
does not serve that loop is cut.

### In

1. **Title screen** (scene + title + Play + Credits) and **credits screen**.
2. **Main screen**: area scene, pelt count, hunter progress bar, hand roster with counts, buy
   buttons, "move on" button, area name. Keyboard and mouse/touch.
3. **Trips**: one hunter trip (PROPOSED 5 s, 1 pelt). Hands run trips on their own timers.
   Wall-clock based; offline catch-up capped (PROPOSED 1 hour).
4. **Two hand kinds** (PROPOSED): *Quiet* (low haul, low patience drain) and *Strong* (high haul,
   high drain). Name and price curve at 1.15x; base prices are tuning numbers in one data table.
5. **Area generator**: seeded; produces an area name, a tile scene layout, and 3 to 5 named beavers
   from a hand-written list (PROPOSED ~30 names) with one of three temperaments (PROPOSED:
   *forgiving*, *grudging*, *indifferent*). Areas persist.
6. **Patience + beating**: hidden per-beaver grudge summed per area; threshold triggers a
   beating; hands lost best-first (PROPOSED: a beating takes enough hands to cover the overshoot,
   at least one); no hands left → full reset.
7. **Reset + scar**: pelts/hands cleared, world kept, patience reduced by a fixed amount, scar
   added to the beaver(s) that landed it. Scar effect per temperament (forgiving: that beaver
   stops adding patience; grudging: adds extra patience; indifferent: no change).
8. **Trip text**: ~10 placeholder lines (the user replaces/extends), picked on trip end.
9. **Save/load**: one JSON blob in `localStorage` under `bhos:save`; autosave; "reset save" on
   the title screen.
10. **Tests** (native `odin test`): trip timing, cost curve, patience accumulation, beating
    casualty order, reset invariants, generator determinism by seed, save round trip.
11. **Ship**: `test.sh`, `build.sh`, `shippit.sh` (tests, build, zip, upload only with `--push`),
    `ITCH_DESCRIPTION.md` with credits and AI-use disclosure, cover 630x500.

### Out (post-slice)

Sound; more than two hand kinds; named hands; gear/speed upgrades; a visible scar/beating
history screen; area-count bounds and old-area dropping; native SDL2 client; gamepad; prestige
beyond scars; per-beaver trip-text variation; Steam/Jest anything.

### Definition of done

- A new player can reach a beating and a reset within roughly 10 to 15 minutes without
  instructions beyond on-screen labels.
- After a reset, a scar is visibly or textually evident on a later trip (so it is not invisible).
- Refreshing the page loses nothing; one itch.io HTML5 build is live and the page text is right.
- `grep -E "your|you're"` over player-facing strings returns nothing.

## 5. Milestones (PROPOSED)

1. **M0 Scaffold (done Oct 15, 2026)**: repo layout, `build.sh`/`test.sh`, canvas shim, blank frame with a DINOBYTE
   string and a Urizen tile on a local server. Decide: build on the Murder Hobo core or lift only
   its framebuffer pieces.
2. **M1 Rules core (done Oct 15, 2026)**: `src/game` with trips, hands, economy, offline catch-up, tests (9). No graphics. Tuning numbers are in `src/game/data.odin`. Patience, beatings and the world are M2; `Trip_Event` is the hook M2 uses.
3. **M2 World (done Oct 15, 2026)**: generator, beavers, patience, beating, reset, scars, tests (20 in total). See section 8.
4. **M3 Screens**: title, main, credits, trip text, save/load.
5. **M4 Ship**: description, cover, screenshots, `--push` after the user says so.

## 6. Decisions on the slice (October 15, 2026)

1. **Scope accepted** as in section 4, with two hand kinds: Quiet (low haul, low patience drain) and Strong (high haul, high drain).
2. **Hands drain patience.** Same meter as the hunter's trips.
3. **Offline catch-up, capped at 1 hour.** Patience builds while away, so a beating can arrive offline.
4. **Build layout: Turn Left at the Cow** (pure rules package, thin web layer, canvas shim, web only). The Murder Hobo core and a native client are post-slice.
5. **Scars show** as a mark on the beaver list and in the trip text.

## 7. Still open

- Hand kind names and the trip-text lines (the user's jokes).
- Itch page slug and content tags (the user creates the page).
- Tuning numbers (trip length, base prices, patience per trip, reset reduction): settle with a prototype.

## 8. How M2 resolved the details (PROPOSED, all tunable in `src/game/data.odin`)

- **Ticks.** The simulation runs in 250 ms ticks on an absolute clock, so one big `step` equals many small ones, beatings included. A test proves it.
- **Where drain goes.** Every trip (hunter or hand) adds its drain to **one beaver of the current area, round-robin**, so there is no randomness at play time. Hands work in the current area; moving on leaves the old one to cool.
- **Patience** is the sum of the area's beaver grudges; the **limit** is 30 per beaver. Checked once per tick.
- **Beating.** Force is the area's total patience. Hands absorb it, **Strong before Quiet** (20 per Quiet hand, 60 per Strong), at least one hand per beating. If hands run out the run resets.
- **After a beating** every beaver's grudge in that area halves. A **full reset** also clears pelts, hands and the trip, and takes 10 grudge off every beaver everywhere. The world is kept.
- **Scars** are only earned on a full reset, by the beaver with the biggest grudge (lowest index on a tie). Scarred *Forgiving* beavers add no patience; scarred *Grudging* ones add double; *Indifferent* ones are unchanged.
- **Cooling.** Beavers of areas yer are not in lose 1 grudge every 10 s.
- **World.** Seeded and deterministic per (seed, index); 3 to 5 beavers per area with distinct names; at most 32 areas, after which "move on" cycles through them (the slice's answer to "what bounds the world").
- **Placeholder lists.** 30 beaver names and 12 area names in `data.odin` are placeholders; the user writes the real ones.
- **Known feel risk.** One hand left alone for an hour will be beaten and reset, because drain outpaces cooling in the current area. That is the pressure working, but tune it once there is a screen.
