package game

// Every tuning number lives here so a prototype can retune the game from one place.
// All of these are PROPOSED (docs/DESIGN.md) and none is final.

OFFLINE_CAP_MS :: 60 * 60 * 1000 // away time that counts when the page returns
COST_GROWTH :: 1.15 // each hand of a kind costs this much more than the last

HUNTER_TRIP_MS :: 5_000
HUNTER_HAUL :: 1
HUNTER_DRAIN :: 2 // patience a trip adds; unused until M2

Hand_Kind :: enum {
	Quiet,
	Strong,
}

Hand_Def :: struct {
	base_cost: u64, // pelts for the first hand
	haul:      u64, // pelts one hand brings back per trip
	trip_ms:   u64,
	drain:     u64, // patience one hand's trip adds; unused until M2
}

HAND_DEFS := [Hand_Kind]Hand_Def {
	.Quiet  = {base_cost = 10, haul = 1, trip_ms = 8_000, drain = 1},
	.Strong = {base_cost = 50, haul = 6, trip_ms = 12_000, drain = 5},
}
