// Save format: a small header plus the raw Game (it holds no pointers). The header lets a
// changed game reject an old save instead of misreading it.
package game

import "core:mem"

Save_Header :: struct {
	magic:       u32,
	version:     u32,
	size:        u32, // size_of(Game) when written
	saved_at_ms: u64, // wall clock, supplied by the platform, for offline catch-up
}

SAVE_BYTES :: size_of(Save_Header) + size_of(Game)

// Writes into `out`; returns the byte count, or 0 if `out` is too small.
save_to_bytes :: proc(g: ^Game, saved_at_ms: u64, out: []u8) -> int {
	if len(out) < SAVE_BYTES {
		return 0
	}
	header := Save_Header {
		magic       = SAVE_MAGIC,
		version     = SAVE_VERSION,
		size        = size_of(Game),
		saved_at_ms = saved_at_ms,
	}
	mem.copy(raw_data(out), &header, size_of(Save_Header))
	mem.copy(raw_data(out[size_of(Save_Header):]), g, size_of(Game))
	return SAVE_BYTES
}

// Rejects anything that is the wrong size, version or shape, rather than trusting it.
load_from_bytes :: proc(data: []u8) -> (g: Game, saved_at_ms: u64, ok: bool) {
	if len(data) != SAVE_BYTES {
		return
	}
	header: Save_Header
	mem.copy(&header, raw_data(data), size_of(Save_Header))
	if header.magic != SAVE_MAGIC || header.version != SAVE_VERSION || header.size != size_of(Game) {
		return
	}
	mem.copy(&g, raw_data(data[size_of(Save_Header):]), size_of(Game))
	if !valid(&g) {
		g = {}
		return
	}
	return g, header.saved_at_ms, true
}

@(private)
valid :: proc(g: ^Game) -> bool {
	if g.area_count < 1 || g.area_count > MAX_AREAS {
		return false
	}
	if g.current_area < 0 || g.current_area >= g.area_count {
		return false
	}
	if g.tick_pending >= TICK_MS || g.cool_ms >= COOL_INTERVAL_MS || g.hunter_ms >= HUNTER_TRIP_MS {
		return false
	}
	for kind in Hand_Kind {
		if g.hand_ms[kind] >= HAND_DEFS[kind].trip_ms {
			return false
		}
	}
	for i in 0 ..< g.area_count {
		a := &g.areas[i]
		if int(a.name) >= len(AREA_NAMES) {
			return false
		}
		if a.beaver_count < MIN_BEAVERS || a.beaver_count > MAX_BEAVERS {
			return false
		}
		for b in 0 ..< a.beaver_count {
			beaver := &a.beavers[b]
			if int(beaver.name) >= len(BEAVER_NAMES) {
				return false
			}
			if int(beaver.temperament) < 0 || int(beaver.temperament) >= len(Temperament) {
				return false
			}
		}
	}
	return true
}
