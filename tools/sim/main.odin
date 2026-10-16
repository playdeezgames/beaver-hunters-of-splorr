// Bot-play balance simulation: runs the pure game package with simple policies over many seeds
// and prints how the economy and the beatings behave. Not shipped.
//   odin run tools/sim -collection:tggd=src
package main

import "core:fmt"
import "core:slice"
import game "tggd:game"

SEEDS :: 200
HORIZON_S :: 120 * 60
CHECKPOINTS_MIN :: [?]int{10, 30, 60, 120}
MOVE_AT :: 0.6 // bots move on when an area's patience passes this fraction of its limit

Policy :: enum {
	Stay, // hunts and hires, never moves on
	Stay_Then_Away, // as Stay for 5 minutes, then leaves the tab alone
	New_Area, // moves on to a brand new area when the current one is touchy
	Rotate3, // cycles through three remembered areas
}

Run :: struct {
	earned_at:     [len(CHECKPOINTS_MIN)]u64,
	hands_at:      [len(CHECKPOINTS_MIN)]u64,
	resets:        u64,
	beatings:      u64,
	first_beating: f64, // seconds, -1 if never
	first_reset:   f64,
	first_hand:    f64,
}

patience_fraction :: proc(g: ^game.Game) -> f64 {
	a := &g.areas[g.current_area]
	return f64(game.area_patience(a)) / f64(game.area_limit(a, g.current_area))
}

// Buy the hand with the cheapest cost per pelt per second, once it is affordable.
shop :: proc(g: ^game.Game) -> bool {
	best: game.Hand_Kind
	best_value := max(f64)
	// The hunter upgrade competes on the same measure: cost per extra pelt per second of hunting
	// (a hunter trip takes HUNTER_TRIP_MS plus a re-press, so count it as always hunting).
	upgrade_income := f64(game.HUNTER_HAUL_PER_LEVEL) / (f64(game.HUNTER_TRIP_MS) / 1000)
	upgrade_value := f64(game.hunter_upgrade_cost(g.hunter_level)) / upgrade_income
	for kind in game.Hand_Kind {
		def := game.HAND_DEFS[kind]
		income := f64(def.haul) / (f64(def.trip_ms) / 1000)
		value := f64(game.hand_cost(kind, g.bought[kind])) / income
		if value < best_value {
			best_value, best = value, kind
		}
	}
	if upgrade_value < best_value {
		return game.buy_hunter_upgrade(g)
	}
	return game.buy_hand(g, best)
}

simulate :: proc(policy: Policy, seed: u64) -> Run {
	g := game.new_game(seed)
	run := Run {
		first_beating = -1,
		first_reset   = -1,
		first_hand    = -1,
	}
	earned: u64
	total_steps := HORIZON_S * 1000 / game.TICK_MS
	cp_steps: [len(CHECKPOINTS_MIN)]int
	for m, i in CHECKPOINTS_MIN {
		cp_steps[i] = m * 60 * 1000 / game.TICK_MS
	}
	next_cp := 0
	for s in 0 ..< total_steps {
		t_s := f64(s) * f64(game.TICK_MS) / 1000
		active := policy != .Stay_Then_Away || t_s < 5 * 60
		if active {
			if !g.hunter_out {
				game.start_hunt(&g)
			}
			for shop(&g) {
				if run.first_hand < 0 {
					run.first_hand = t_s
				}
			}
			if policy == .New_Area && patience_fraction(&g) >= MOVE_AT {
				game.move_on(&g)
			}
			if policy == .Rotate3 && patience_fraction(&g) >= MOVE_AT {
				for g.area_count < 3 {
					game.move_on(&g)
				}
				game.go_to_area(&g, (g.current_area + 1) % 3)
			}
		}
		game.step(&g, game.TICK_MS)
		earned += g.last_hunter.pelts
		for kind in game.Hand_Kind {
			earned += g.last_hands[kind].pelts
		}
		if g.last_beating.beatings > 0 && run.first_beating < 0 {
			run.first_beating = t_s
		}
		if g.last_beating.resets > 0 && run.first_reset < 0 {
			run.first_reset = t_s
		}
		if next_cp < len(cp_steps) && s + 1 == cp_steps[next_cp] {
			run.earned_at[next_cp] = earned
			run.hands_at[next_cp] = g.hands[.Quiet] + g.hands[.Strong]
			next_cp += 1
		}
	}
	run.resets = g.resets
	run.beatings = g.beatings
	return run
}

percentile :: proc(xs: []f64, p: f64) -> f64 {
	if len(xs) == 0 {
		return 0
	}
	slice.sort(xs)
	return xs[int(p * f64(len(xs) - 1))]
}

main :: proc() {
	cps := CHECKPOINTS_MIN
	for policy in Policy {
		runs := make([]Run, SEEDS)
		defer delete(runs)
		for i in 0 ..< SEEDS {
			runs[i] = simulate(policy, u64(i + 1))
		}
		fmt.printfln("\n=== %v (%d seeds, %d min) ===", policy, SEEDS, HORIZON_S / 60)

		xs := make([]f64, SEEDS)
		defer delete(xs)
		for cp, ci in cps {
			for r, i in runs {
				xs[i] = f64(r.earned_at[ci])
			}
			e50 := percentile(xs, 0.5)
			e10 := percentile(xs, 0.1)
			e90 := percentile(xs, 0.9)
			for r, i in runs {
				xs[i] = f64(r.hands_at[ci])
			}
			h50 := percentile(xs, 0.5)
			fmt.printfln("  by %3d min: pelts earned p10/p50/p90 = %7.0f / %7.0f / %7.0f   hands held (median) %4.0f", cp, e10, e50, e90, h50)
		}

		never_beaten, never_reset: int
		first_hand, first_beating, first_reset, resets, beatings: [dynamic]f64
		defer delete(first_hand)
		defer delete(first_beating)
		defer delete(first_reset)
		defer delete(resets)
		defer delete(beatings)
		for r in runs {
			append(&first_hand, r.first_hand)
			append(&resets, f64(r.resets))
			append(&beatings, f64(r.beatings))
			if r.first_beating < 0 {never_beaten += 1} else {append(&first_beating, r.first_beating)}
			if r.first_reset < 0 {never_reset += 1} else {append(&first_reset, r.first_reset)}
		}
		fmt.printfln("  first hand (median): %.0f s", percentile(first_hand[:], 0.5))
		fmt.printfln("  first beating: median %.0f s, never in %d of %d runs", percentile(first_beating[:], 0.5), never_beaten, SEEDS)
		fmt.printfln("  first full reset: median %.0f s, never in %d of %d runs", percentile(first_reset[:], 0.5), never_reset, SEEDS)
		fmt.printfln("  over the horizon: beatings median %.0f, full resets median %.0f", percentile(beatings[:], 0.5), percentile(resets[:], 0.5))
	}
}
