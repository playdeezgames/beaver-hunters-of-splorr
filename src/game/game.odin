// Pure rules: no platform imports, so it tests natively with `odin test`.
// Time enters only as `dt_ms`, so the same code runs live and as offline catch-up.
package game

import "core:math"

// What finished during the last `step`. M2 turns these into patience.
Trip_Event :: struct {
	trips: u64, // trips completed
	pelts: u64, // pelts brought back
}

Game :: struct {
	elapsed_ms:    u64,
	pelts:         u64,
	hunter_out:    bool,
	hunter_ms:     u64, // time spent on the current trip
	hands:         [Hand_Kind]u64, // hands owned
	hand_ms:       [Hand_Kind]u64, // progress into each kind's current cycle
	last_hunter:   Trip_Event,
	last_hands:    [Hand_Kind]Trip_Event,
}

new_game :: proc() -> Game {
	return Game{}
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

// Advances the simulation by `dt_ms` of wall-clock time. Any `dt_ms` is exact: one big step
// gives the same result as many small ones.
step :: proc(g: ^Game, dt_ms: u64) {
	g.elapsed_ms += dt_ms
	g.last_hunter = {}
	g.last_hands = {}

	if g.hunter_out {
		g.hunter_ms += dt_ms
		if g.hunter_ms >= HUNTER_TRIP_MS {
			g.hunter_out = false
			g.hunter_ms = 0
			g.last_hunter = {trips = 1, pelts = HUNTER_HAUL}
			g.pelts += HUNTER_HAUL
		}
	}

	for kind in Hand_Kind {
		count := g.hands[kind]
		if count == 0 {
			continue
		}
		def := HAND_DEFS[kind]
		g.hand_ms[kind] += dt_ms
		cycles := g.hand_ms[kind] / def.trip_ms
		g.hand_ms[kind] %= def.trip_ms
		if cycles > 0 {
			trips := cycles * count
			pelts := trips * def.haul
			g.last_hands[kind] = {trips = trips, pelts = pelts}
			g.pelts += pelts
		}
	}
}

// Applies time spent away, capped at OFFLINE_CAP_MS. Returns the milliseconds that counted.
catch_up :: proc(g: ^Game, away_ms: u64) -> u64 {
	counted := min(away_ms, OFFLINE_CAP_MS)
	step(g, counted)
	return counted
}
