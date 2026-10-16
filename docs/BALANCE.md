# Balance notes (simulation)

`tools/sim` plays the pure game package with four bot policies over 200 seeds and 2 hours of game time:

```bash
/home/yermom/ODIN/odin run tools/sim -collection:tggd=src -o:speed
```

Bots hunt whenever the hunter is idle and buy the hand with the best cost per income. Policies: **Stay** (never move on),
**Stay_Then_Away** (as Stay for 5 minutes, then leave the tab alone, so the offline cap applies), **New_Area** (move on to a
brand new area when the current one passes 60% of its limit), **Rotate3** (cycle three remembered areas at the same trigger).
Bots can see patience; players cannot, so real play is clumsier than this.

## Findings (patience limit 30 per beaver, cooling every 10 s, as of M3)

| Policy | First full reset (median) | Resets in 2 h (median) | Pelts earned in 1 h (median) |
| --- | --- | --- | --- |
| Stay | 214 s | 38 | ~1,250 |
| Stay_Then_Away | 214 s | 2 | ~160 |
| New_Area | never | 0 | ~27,000 |
| Rotate3 | 2,890 s (131 of 200 never) | 0 | ~4,800 |

1. **Fresh areas are a free exploit.** Moving on to a new area is free and the world is endless, so a bot that always runs to a
   new area is never reset and earns 5 to 20 times what the other policies earn. Remembering and rotating areas, which the
   design calls the skill, is never needed. This is the biggest hole.
2. **Staying is punished fast.** A hunt-and-hire player is wiped about 3.5 minutes in, and every few minutes after, before a
   hidden meter can be learned.
3. **Leaving with hands is a wipe.** After the bot leaves, the offline hour beats and resets it within about 6 minutes. The
   user chose to keep offline beatings; this quantifies it.
4. **Rotating is knife-edge.** At 30 per beaver most bots never reset; at 60, 11 of 200 never reset and the rest do once or
   three times; at 90, every bot resets eventually. Cooling every 5 s instead of 10 s makes rotating safe (never reset) and
   changes nothing for the other policies.
5. **Hands cycle in lockstep.** All hands of a kind finish on the same tick, so drain arrives in bursts of `count * drain`.
   That caps how many hands one area can hold (about the limit divided by drain) however carefully the player rotates.

## Sweep of the patience limit per beaver (cooling 10 s)

| Limit per beaver | Stay: first reset | Stay: resets in 2 h | Rotate3: never reset | New_Area: pelts in 1 h |
| --- | --- | --- | --- | --- |
| 30 | 214 s | 38 | 131 of 200 | ~27,000 |
| 60 | 305 s | 28 | 11 of 200 (median first reset 1,690 s) | ~37,000 |
| 90 | 362 s | 24 | 0 of 200 (median first reset 886 s) | ~42,000 |

Raising the limit helps the learning window a little but widens the gap with New_Area. The fix for finding 1 is structural, not a
number.

## After the first retune (October 16, 2026)

Changes, all in `src/game/data.odin` and `game.odin`: limit per beaver 30 to 60; deeper areas (higher index) are touchier by 3 per
beaver per step (floor 20) and pay 10% more per trip each step; hand prices follow hands **bought this run**, not hands owned, so a
beating no longer discounts the rebuy (a full reset starts a new run at base prices).

| Policy | First full reset (median) | Resets in 2 h (median) | Pelts earned in 1 h (median) |
| --- | --- | --- | --- |
| Stay | 305 s | 28 | ~1,750 |
| Stay_Then_Away | 306 s | 1 | ~190 |
| New_Area | never | 0 | ~36,000 |
| Rotate3 | 962 s (0 of 200 never) | 7 | ~4,800 |

- Depth scaling alone made the fresh-area bot richer (about 150,000 pelts in 2 h): beatings only cost hands, which were rebought
  cheaply. Pricing by hands bought brought it to about 36,000 an hour with 22 beatings.
- Rotating now resets about every 17 minutes of play; staying about every 5.
- **Still true:** a fresh area has no grudges, so always moving on is the best bot strategy, about 7 times Rotate3. The bot sees the
  patience meter; a player cannot, so real play will take more beatings. Revisit after the user plays.
