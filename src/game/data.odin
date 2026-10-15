package game

// Every tuning number lives here so a prototype can retune the game from one place.
// All of these are PROPOSED (docs/DESIGN.md) and none is final.

TICK_MS :: 250 // the simulation runs in ticks on an absolute clock, so step is exact for any dt
OFFLINE_CAP_MS :: 60 * 60 * 1000 // away time that counts when the page returns
COST_GROWTH :: 1.15 // each hand of a kind costs this much more than the last

HUNTER_TRIP_MS :: 5_000
HUNTER_HAUL :: 1
HUNTER_DRAIN :: 2 // patience one hunter trip adds to the area

Hand_Kind :: enum {
	Quiet,
	Strong,
}

Hand_Def :: struct {
	base_cost: u64, // pelts for the first hand
	haul:      u64, // pelts one hand brings back per trip
	trip_ms:   u64,
	drain:     u64, // patience one hand's trip adds
	absorb:    u64, // patience of a beating one hand takes in its place
}

HAND_DEFS := [Hand_Kind]Hand_Def {
	.Quiet  = {base_cost = 10, haul = 1, trip_ms = 8_000, drain = 1, absorb = 20},
	.Strong = {base_cost = 50, haul = 6, trip_ms = 12_000, drain = 5, absorb = 60},
}

// The beavers go after the most valuable hands first.
BEST_FIRST :: [?]Hand_Kind{.Strong, .Quiet}

// The world.
MAX_AREAS :: 32 // slice bound on the "endless" world; past it, moving on cycles through them
MIN_BEAVERS :: 3
MAX_BEAVERS :: 5
PATIENCE_PER_BEAVER :: 30 // an area's limit is this times its beavers
COOL_INTERVAL_MS :: 10_000 // elsewhere, every beaver of an area we are not in forgets 1 point
RESET_RELIEF :: 10 // a full reset takes this much grudge off every beaver everywhere
SCARRED_GRUDGING_FACTOR :: 2 // a scarred grudging beaver adds this much more patience per trip

Temperament :: enum {
	Forgiving, // once scarred, adds no patience
	Grudging, // once scarred, adds more
	Indifferent, // scars change nothing
}

// PLACEHOLDER names so the generator can be tested. The user writes the real lists, and the
// jokes live there.
BEAVER_NAMES := [?]string {
	"Alder", "Birch", "Bramble", "Clover", "Cedar", "Dapple", "Elm", "Fennel", "Gorse", "Hazel",
	"Ivy", "Juniper", "Kestrel", "Laurel", "Maple", "Nettle", "Oak", "Poplar", "Quince", "Rowan",
	"Sorrel", "Thistle", "Umber", "Vetch", "Willow", "Yarrow", "Aspen", "Burdock", "Cattail", "Dock",
}

AREA_NAMES := [?]string {
	"Mill Creek", "Long Marsh", "Pine Hollow", "Stony Bend", "Cold Pond", "Alder Flats",
	"Fox Run", "Deep Reach", "Muddy Elbow", "High Meadow", "Thorn Brook", "Quiet Water",
}
