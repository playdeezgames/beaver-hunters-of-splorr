// The world: areas of named beavers, generated deterministically from a seed.
package game

Beaver :: struct {
	name:        u8, // index into BEAVER_NAMES
	temperament: Temperament,
	grudge:      u64, // hidden; the beaver's share of the area's patience meter
	scars:       u32, // full resets this beaver landed
}

Area :: struct {
	name:         u8, // index into AREA_NAMES
	beaver_count: int,
	beavers:      [MAX_BEAVERS]Beaver,
	trips:        u64, // trips taken here; spreads drain round-robin, so no randomness at play time
}

// splitmix64: tiny, fast, and identical on every platform.
@(private)
rng_next :: proc(state: ^u64) -> u64 {
	state^ += 0x9E3779B97F4A7C15
	z := state^
	z = (z ~ (z >> 30)) * 0xBF58476D1CE4E5B9
	z = (z ~ (z >> 27)) * 0x94D049BB133111EB
	return z ~ (z >> 31)
}

// The same (seed, index) always gives the same area.
generate_area :: proc(seed: u64, index: int) -> Area {
	state := seed ~ (u64(index) + 1) * 0xD1B54A32D192ED03
	area: Area
	area.name = u8(rng_next(&state) % len(AREA_NAMES))
	area.beaver_count = MIN_BEAVERS + int(rng_next(&state) % (MAX_BEAVERS - MIN_BEAVERS + 1))

	// Partial Fisher-Yates over the name list, so names are distinct inside an area.
	pool: [len(BEAVER_NAMES)]u8
	for i in 0 ..< len(pool) {
		pool[i] = u8(i)
	}
	for i in 0 ..< area.beaver_count {
		j := i + int(rng_next(&state) % u64(len(pool) - i))
		pool[i], pool[j] = pool[j], pool[i]
		area.beavers[i].name = pool[i]
		area.beavers[i].temperament = Temperament(rng_next(&state) % len(Temperament))
	}
	return area
}

area_patience :: proc(a: ^Area) -> u64 {
	total: u64
	for i in 0 ..< a.beaver_count {
		total += a.beavers[i].grudge
	}
	return total
}

// Deeper areas (higher index) are touchier: the limit per beaver falls with depth, down to a floor.
area_limit :: proc(a: ^Area, depth: int) -> u64 {
	per_beaver := max(i64(PATIENCE_PER_BEAVER) - i64(depth) * DEPTH_LIMIT_STEP, MIN_PATIENCE_PER_BEAVER)
	return u64(a.beaver_count) * u64(per_beaver)
}

// Deeper areas pay more per trip, in percent of the base haul.
area_pay_percent :: proc(depth: int) -> u64 {
	return 100 + u64(depth) * DEPTH_PAY_PERCENT
}

// What one trip with base `drain` adds to this beaver's grudge, scars considered.
@(private)
trip_drain :: proc(b: ^Beaver, drain: u64) -> u64 {
	if b.scars == 0 {
		return drain
	}
	switch b.temperament {
	case .Forgiving:
		return 0
	case .Grudging:
		return drain * SCARRED_GRUDGING_FACTOR
	case .Indifferent:
		return drain
	}
	return drain
}
