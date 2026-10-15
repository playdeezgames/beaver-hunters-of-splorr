// Pure rules: no platform imports, so it tests natively with `odin test`.
// Time enters only as `dt_ms`, so the same code runs live and as offline catch-up.
package game

import "core:math"

// What finished during the last `step`.
Trip_Event :: struct {
	trips: u64, // trips completed
	pelts: u64, // pelts brought back
}

// What finished during the last `step`.
Beating_Event :: struct {
	beatings:   u64,
	hands_lost: [Hand_Kind]u64,
	resets:     u64, // full resets
	scarred:    bool, // the latest reset marked a beaver
	scar_area:  int,
	scar_beaver: int,
}

Game :: struct {
	seed:         u64,
	elapsed_ms:   u64,
	tick_pending: u64, // time not yet run as a tick
	cool_ms:      u64,
	pelts:        u64,
	hunter_out:   bool,
	hunter_ms:    u64, // time spent on the current trip
	hands:        [Hand_Kind]u64, // hands owned
	hand_ms:      [Hand_Kind]u64, // progress into each kind's current cycle
	areas:        [MAX_AREAS]Area,
	area_count:   int,
	current_area: int,
	beatings:     u64, // lifetime
	resets:       u64, // lifetime
	last_hunter:  Trip_Event,
	last_hands:   [Hand_Kind]Trip_Event,
	last_beating: Beating_Event,
}

new_game :: proc(seed: u64 = 1) -> Game {
	g := Game{seed = seed, area_count = 1}
	g.areas[0] = generate_area(seed, 0)
	return g
}

// Moves to a new area, or (once MAX_AREAS exist) the next remembered one. The area left stays
// as it was and cools while yer are away.
move_on :: proc(g: ^Game) {
	if g.area_count < MAX_AREAS {
		g.areas[g.area_count] = generate_area(g.seed, g.area_count)
		g.current_area = g.area_count
		g.area_count += 1
	} else {
		g.current_area = (g.current_area + 1) % g.area_count
	}
}

// Returns to a remembered area. False if there is no such area.
go_to_area :: proc(g: ^Game, index: int) -> bool {
	if index < 0 || index >= g.area_count {
		return false
	}
	g.current_area = index
	return true
}

// Sends the hunter out. False if already out.
start_hunt :: proc(g: ^Game) -> bool {
	if g.hunter_out {
		return false
	}
	g.hunter_out = true
	g.hunter_ms = 0
	return true
}

// Price of the next hand of a kind: steep curve, rounded up.
hand_cost :: proc(kind: Hand_Kind, owned: u64) -> u64 {
	base := f64(HAND_DEFS[kind].base_cost)
	return u64(math.ceil(base * math.pow(COST_GROWTH, f64(owned))))
}

// Buys one hand. False (and nothing changes) if yer cannot afford it.
buy_hand :: proc(g: ^Game, kind: Hand_Kind) -> bool {
	cost := hand_cost(kind, g.hands[kind])
	if g.pelts < cost {
		return false
	}
	g.pelts -= cost
	g.hands[kind] += 1
	return true
}

// Advances the simulation by `dt_ms` of wall-clock time. The work runs in fixed ticks on an
// absolute clock, so one big step gives exactly the same result as many small ones.
step :: proc(g: ^Game, dt_ms: u64) {
	g.elapsed_ms += dt_ms
	g.last_hunter = {}
	g.last_hands = {}
	g.last_beating = {}

	g.tick_pending += dt_ms
	for g.tick_pending >= TICK_MS {
		g.tick_pending -= TICK_MS
		tick(g)
	}
}

@(private)
tick :: proc(g: ^Game) {
	if g.hunter_out {
		g.hunter_ms += TICK_MS
		if g.hunter_ms >= HUNTER_TRIP_MS {
			g.hunter_out = false
			g.hunter_ms = 0
			g.last_hunter.trips += 1
			g.last_hunter.pelts += HUNTER_HAUL
			g.pelts += HUNTER_HAUL
			add_trips(g, HUNTER_DRAIN, 1)
		}
	}

	for kind in Hand_Kind {
		count := g.hands[kind]
		if count == 0 {
			continue
		}
		def := HAND_DEFS[kind]
		g.hand_ms[kind] += TICK_MS
		if g.hand_ms[kind] >= def.trip_ms {
			g.hand_ms[kind] -= def.trip_ms
			pelts := count * def.haul
			g.last_hands[kind].trips += count
			g.last_hands[kind].pelts += pelts
			g.pelts += pelts
			add_trips(g, def.drain, count)
		}
	}

	// Areas yer are not in cool off; that is what makes moving on work.
	g.cool_ms += TICK_MS
	if g.cool_ms >= COOL_INTERVAL_MS {
		g.cool_ms -= COOL_INTERVAL_MS
		for i in 0 ..< g.area_count {
			if i == g.current_area {
				continue
			}
			for b in 0 ..< g.areas[i].beaver_count {
				beaver := &g.areas[i].beavers[b]
				beaver.grudge -= min(beaver.grudge, 1)
			}
		}
	}

	area := &g.areas[g.current_area]
	if area_patience(area) >= area_limit(area) {
		beat_up(g)
	}
}

// Each trip's drain goes to one beaver of the current area, round-robin.
@(private)
add_trips :: proc(g: ^Game, drain, trips: u64) {
	area := &g.areas[g.current_area]
	for _ in 0 ..< trips {
		b := &area.beavers[int(area.trips % u64(area.beaver_count))]
		area.trips += 1
		b.grudge += trip_drain(b, drain)
	}
}

// The beavers of the current area gang up. Hands take it first, best first; if the hands run
// out, the run resets and the beaver with the biggest grudge is scarred.
@(private)
beat_up :: proc(g: ^Game) {
	area := &g.areas[g.current_area]
	remaining := area_patience(area)

	g.beatings += 1
	g.last_beating.beatings += 1

	for kind in BEST_FIRST {
		absorb := HAND_DEFS[kind].absorb
		for g.hands[kind] > 0 && remaining > 0 {
			g.hands[kind] -= 1
			g.last_beating.hands_lost[kind] += 1
			remaining -= min(absorb, remaining)
		}
		if g.hands[kind] == 0 {
			g.hand_ms[kind] = 0
		}
	}

	if remaining > 0 {
		// The ringleader is the beaver with the biggest grudge (lowest index on a tie).
		leader := 0
		for i in 1 ..< area.beaver_count {
			if area.beavers[i].grudge > area.beavers[leader].grudge {
				leader = i
			}
		}
		area.beavers[leader].scars += 1
		g.last_beating.scarred = true
		g.last_beating.scar_area = g.current_area
		g.last_beating.scar_beaver = leader
		g.last_beating.resets += 1
		g.resets += 1
	}

	// They have vented, hands or no hands.
	for i in 0 ..< area.beaver_count {
		area.beavers[i].grudge /= 2
	}

	if remaining > 0 {
		// Full reset: pelts, hands and the trip in progress go; the world stays, a little calmer.
		g.pelts = 0
		g.hands = {}
		g.hand_ms = {}
		g.hunter_out = false
		g.hunter_ms = 0
		for a in 0 ..< g.area_count {
			for b in 0 ..< g.areas[a].beaver_count {
				beaver := &g.areas[a].beavers[b]
				beaver.grudge -= min(beaver.grudge, RESET_RELIEF)
			}
		}
	}
}

// Applies time spent away, capped at OFFLINE_CAP_MS. Returns the milliseconds that counted.
// A beating can arrive while yer are away.
catch_up :: proc(g: ^Game, away_ms: u64) -> u64 {
	counted := min(away_ms, OFFLINE_CAP_MS)
	step(g, counted)
	return counted
}
