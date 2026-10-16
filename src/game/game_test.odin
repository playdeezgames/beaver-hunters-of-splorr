#+build !js
package game

import "core:testing"

// A quiet area for tests that are about something else: every beaver is far from fed up.
@(private = "file")
calm :: proc(g: ^Game) {
	for i in 0 ..< g.area_count {
		for b in 0 ..< g.areas[i].beaver_count {
			g.areas[i].beavers[b].grudge = 0
		}
	}
}

@(private = "file")
cur :: proc(g: ^Game) -> ^Area {
	return &g.areas[g.current_area]
}

// --- M1: trips, hands, economy ---

@(test)
step_accumulates_time :: proc(t: ^testing.T) {
	g := new_game()
	step(&g, 16)
	step(&g, 16)
	testing.expect_value(t, g.elapsed_ms, 32)
}

@(test)
hunter_trip_pays_after_its_duration :: proc(t: ^testing.T) {
	g := new_game()
	testing.expect(t, start_hunt(&g), "starts")
	step(&g, HUNTER_TRIP_MS - 1)
	testing.expect_value(t, g.pelts, 0)
	testing.expect(t, g.hunter_out, "still out")
	step(&g, 1)
	testing.expect_value(t, g.pelts, HUNTER_HAUL)
	testing.expect(t, !g.hunter_out, "back")
	testing.expect_value(t, g.last_hunter.trips, 1)
}

@(test)
hunter_cannot_start_twice_and_does_not_repeat :: proc(t: ^testing.T) {
	g := new_game()
	testing.expect(t, start_hunt(&g), "first start")
	testing.expect(t, !start_hunt(&g), "second start refused")
	step(&g, HUNTER_TRIP_MS * 10)
	testing.expect_value(t, g.pelts, HUNTER_HAUL) // idle hunter stays home
}

@(test)
hand_cost_follows_the_curve :: proc(t: ^testing.T) {
	testing.expect_value(t, hand_cost(.Quiet, 0), 10)
	testing.expect_value(t, hand_cost(.Quiet, 1), 12) // 11.5 rounds up
	testing.expect_value(t, hand_cost(.Quiet, 2), 14) // 13.225 rounds up
	testing.expect_value(t, hand_cost(.Strong, 0), 50)
	prev := hand_cost(.Strong, 0)
	for n in 1 ..< 40 {
		c := hand_cost(.Strong, u64(n))
		testing.expectf(t, c > prev, "cost rises at %d", n)
		prev = c
	}
}

@(test)
buying_needs_pelts_and_charges_them :: proc(t: ^testing.T) {
	g := new_game()
	g.pelts = 9
	testing.expect(t, !buy_hand(&g, .Quiet), "cannot afford")
	testing.expect_value(t, g.pelts, 9)
	testing.expect_value(t, g.hands[.Quiet], 0)
	g.pelts = 10
	testing.expect(t, buy_hand(&g, .Quiet), "affords")
	testing.expect_value(t, g.pelts, 0)
	testing.expect_value(t, g.hands[.Quiet], 1)
	testing.expect_value(t, hand_cost(.Quiet, g.bought[.Quiet]), 12)
}

@(test)
hands_work_on_their_own_and_stack :: proc(t: ^testing.T) {
	g := new_game()
	g.hands[.Quiet] = 3
	step(&g, HAND_DEFS[.Quiet].trip_ms)
	testing.expect_value(t, g.pelts, 3 * HAND_DEFS[.Quiet].haul)
	testing.expect_value(t, g.last_hands[.Quiet].trips, 3)
	testing.expect_value(t, g.last_hands[.Strong].trips, 0)
}

@(test)
one_big_step_equals_many_small_ones :: proc(t: ^testing.T) {
	// Long enough to include beatings and a reset, so the whole machine is compared.
	big, small := new_game(7), new_game(7)
	for g in ([]^Game{&big, &small}) {
		g.hands[.Quiet] = 4
		g.hands[.Strong] = 2
	}
	total: u64 = 10 * 60 * 1000 + 777
	step(&big, total)
	for _ in 0 ..< total / 7 {
		step(&small, 7)
	}
	step(&small, total % 7)
	testing.expect_value(t, big.pelts, small.pelts)
	testing.expect_value(t, big.hands, small.hands)
	testing.expect_value(t, big.beatings, small.beatings)
	testing.expect_value(t, big.resets, small.resets)
	testing.expect(t, big.beatings > 0, "the comparison covered a beating")
	for i in 0 ..< big.area_count {
		testing.expect(t, big.areas[i] == small.areas[i], "areas match")
	}
}

@(test)
catch_up_is_capped :: proc(t: ^testing.T) {
	g := new_game()
	counted := catch_up(&g, 24 * 60 * 60 * 1000)
	testing.expect_value(t, counted, OFFLINE_CAP_MS)
	testing.expect_value(t, g.elapsed_ms, OFFLINE_CAP_MS)
}

@(test)
catch_up_pays_hands_when_no_one_is_upset :: proc(t: ^testing.T) {
	g := new_game()
	g.hands[.Quiet] = 1
	catch_up(&g, 60 * 1000) // 7 full 8 s cycles, far under the patience limit
	testing.expect_value(t, g.pelts, 7)
}

@(test)
buying_mid_cycle_keeps_progress :: proc(t: ^testing.T) {
	g := new_game()
	g.hands[.Quiet] = 1
	step(&g, 6_000)
	g.pelts = 100
	buy_hand(&g, .Quiet)
	step(&g, 2_000) // finishes the 8 s cycle for both hands
	testing.expect_value(t, g.last_hands[.Quiet].trips, 2)
}

// --- M2: world, patience, beating, reset, scars ---

@(test)
generator_is_deterministic_and_well_formed :: proc(t: ^testing.T) {
	for seed in ([]u64{1, 2, 99, 0xDEADBEEF}) {
		for index in 0 ..< 10 {
			a, b := generate_area(seed, index), generate_area(seed, index)
			testing.expect(t, a == b, "same seed and index, same area")
			testing.expectf(t, a.beaver_count >= MIN_BEAVERS && a.beaver_count <= MAX_BEAVERS, "count %d", a.beaver_count)
			for i in 0 ..< a.beaver_count {
				for j in i + 1 ..< a.beaver_count {
					testing.expect(t, a.beavers[i].name != a.beavers[j].name, "distinct names")
				}
			}
		}
	}
	testing.expect(t, generate_area(1, 0) != generate_area(2, 0) || generate_area(1, 1) != generate_area(2, 1), "seeds differ")
}

@(test)
hunter_trip_adds_patience :: proc(t: ^testing.T) {
	g := new_game()
	start_hunt(&g)
	step(&g, HUNTER_TRIP_MS)
	testing.expect_value(t, area_patience(cur(&g)), HUNTER_DRAIN)
}

@(test)
drain_is_spread_round_robin :: proc(t: ^testing.T) {
	g := new_game()
	n := cur(&g).beaver_count
	g.hands[.Quiet] = u64(n) // n trips per cycle: one each
	step(&g, HAND_DEFS[.Quiet].trip_ms)
	for i in 0 ..< n {
		testing.expect_value(t, cur(&g).beavers[i].grudge, HAND_DEFS[.Quiet].drain)
	}
}

@(test)
scars_change_how_beavers_take_trips :: proc(t: ^testing.T) {
	forgiving := Beaver{temperament = .Forgiving, scars = 1}
	grudging := Beaver{temperament = .Grudging, scars = 1}
	indifferent := Beaver{temperament = .Indifferent, scars = 1}
	fresh := Beaver{temperament = .Grudging}
	testing.expect_value(t, trip_drain(&forgiving, 4), 0)
	testing.expect_value(t, trip_drain(&grudging, 4), 4 * SCARRED_GRUDGING_FACTOR)
	testing.expect_value(t, trip_drain(&indifferent, 4), 4)
	testing.expect_value(t, trip_drain(&fresh, 4), 4)
}

@(test)
beating_takes_best_hands_first_and_spares_the_run :: proc(t: ^testing.T) {
	g := new_game()
	g.hands[.Strong] = 2
	g.hands[.Quiet] = 5
	g.pelts = 77
	area := cur(&g)
	area.beavers[0].grudge = area_limit(area, g.current_area) // at the limit, so the next tick beats
	step(&g, TICK_MS)
	// Force was the limit; a Strong hand absorbs 60, so the first lost hand is a Strong one.
	testing.expect_value(t, g.last_beating.beatings, 1)
	testing.expect(t, g.last_beating.hands_lost[.Strong] >= 1, "strong hand lost first")
	testing.expect(t, g.hands[.Strong] < 2, "a strong hand is gone")
	testing.expect_value(t, g.resets, 0)
	testing.expect_value(t, g.pelts, 77 + 0)
}

@(test)
no_hands_means_a_full_reset_with_a_scar :: proc(t: ^testing.T) {
	g := new_game()
	move_on(&g) // area 1 so the world has two places to keep
	g.pelts = 500
	g.hunter_out = true
	area := cur(&g)
	area.beavers[1].grudge = area_limit(area, g.current_area) // beaver 1 is the ringleader
	other := &g.areas[0]
	other.beavers[0].grudge = 25
	step(&g, TICK_MS)

	testing.expect_value(t, g.last_beating.resets, 1)
	testing.expect_value(t, g.pelts, 0)
	testing.expect(t, !g.hunter_out, "trip abandoned")
	testing.expect_value(t, area.beavers[1].scars, 1)
	testing.expect_value(t, g.last_beating.scar_beaver, 1)
	testing.expect_value(t, g.area_count, 2) // the world is kept
	testing.expect_value(t, other.beavers[0].grudge, 25 - RESET_RELIEF) // calmer, not cleared
	testing.expect(t, area_patience(area) < area_limit(area, g.current_area), "area is usable again")
}

@(test)
moving_on_lets_an_area_cool_and_it_is_remembered :: proc(t: ^testing.T) {
	g := new_game()
	before := g.areas[0]
	cur(&g).beavers[0].grudge = 5
	move_on(&g)
	testing.expect_value(t, g.current_area, 1)
	step(&g, COOL_INTERVAL_MS * 2)
	testing.expect_value(t, g.areas[0].beavers[0].grudge, 3)
	testing.expect(t, go_to_area(&g, 0), "can go back")
	testing.expect_value(t, g.areas[0].beaver_count, before.beaver_count)
	testing.expect(t, g.areas[0].beavers[0].name == before.beavers[0].name, "same beavers")
	testing.expect(t, !go_to_area(&g, 5), "no such area")
}

@(test)
the_current_area_does_not_cool :: proc(t: ^testing.T) {
	g := new_game()
	cur(&g).beavers[0].grudge = 5
	step(&g, COOL_INTERVAL_MS * 2)
	testing.expect_value(t, cur(&g).beavers[0].grudge, 5)
}

@(test)
a_full_world_cycles_through_remembered_areas :: proc(t: ^testing.T) {
	g := new_game()
	for _ in 0 ..< MAX_AREAS + 3 {
		move_on(&g)
	}
	testing.expect_value(t, g.area_count, MAX_AREAS)
	testing.expect(t, g.current_area >= 0 && g.current_area < MAX_AREAS, "stays in range")
}

@(test)
a_scarred_forgiving_beaver_stops_adding_patience_next_run :: proc(t: ^testing.T) {
	g := new_game()
	area := cur(&g)
	area.beavers[0].temperament = .Forgiving
	area.beavers[0].grudge = area_limit(area, g.current_area)
	step(&g, TICK_MS) // no hands: reset, beaver 0 is scarred
	testing.expect_value(t, area.beavers[0].scars, 1)
	calm(&g)
	area.trips = 0 // the next trip goes to beaver 0
	start_hunt(&g)
	step(&g, HUNTER_TRIP_MS)
	testing.expect_value(t, area_patience(area), 0)
}

// --- M3: save and trip text ---

@(test)
save_round_trips :: proc(t: ^testing.T) {
	g := new_game(42)
	g.hands[.Quiet] = 3
	g.pelts = 123
	move_on(&g)
	step(&g, 12_345)
	buf: [SAVE_BYTES]u8
	n := save_to_bytes(&g, 1_700_000_000_000, buf[:])
	testing.expect_value(t, n, SAVE_BYTES)
	loaded, at, ok := load_from_bytes(buf[:])
	testing.expect(t, ok, "loads")
	testing.expect_value(t, at, 1_700_000_000_000)
	testing.expect(t, loaded == g, "same game")
}

@(test)
save_rejects_bad_data :: proc(t: ^testing.T) {
	g := new_game()
	buf: [SAVE_BYTES]u8
	save_to_bytes(&g, 1, buf[:])

	_, _, ok := load_from_bytes(buf[:SAVE_BYTES - 1])
	testing.expect(t, !ok, "short")

	bad := buf
	bad[0] ~= 0xFF // magic
	_, _, ok = load_from_bytes(bad[:])
	testing.expect(t, !ok, "magic")

	bad = buf
	bad[4] += 1 // version
	_, _, ok = load_from_bytes(bad[:])
	testing.expect(t, !ok, "version")

	broken := g
	broken.current_area = 5 // outside area_count
	save_to_bytes(&broken, 1, bad[:])
	_, _, ok = load_from_bytes(bad[:])
	testing.expect(t, !ok, "current area out of range")

	broken = g
	broken.areas[0].beavers[0].name = 250 // outside the name list
	save_to_bytes(&broken, 1, bad[:])
	_, _, ok = load_from_bytes(bad[:])
	testing.expect(t, !ok, "name out of range")

	_, _, ok = load_from_bytes(nil)
	testing.expect(t, !ok, "empty")
}

@(test)
trip_lines_are_deterministic_and_in_range :: proc(t: ^testing.T) {
	g := new_game(3)
	for _ in 0 ..< 200 {
		area := cur(&g)
		area.trips += 1
		a := pick_trip_line(&g)
		b := pick_trip_line(&g)
		testing.expect(t, a == b, "same state, same line")
		testing.expect(t, a.beaver >= 0 && a.beaver < area.beaver_count, "beaver in range")
		switch a.kind {
		case .Plain:
			testing.expect(t, a.index < len(TRIP_LINES), "plain index")
		case .Named:
			testing.expect(t, a.index < len(NAMED_FRAGMENTS), "named index")
		case .Scarred:
			testing.expect(t, a.index < len(SCARRED_FRAGMENTS), "scarred index")
		}
	}
}

@(test)
a_scarred_beaver_gets_a_line_that_says_so :: proc(t: ^testing.T) {
	g := new_game()
	area := cur(&g)
	for i in 0 ..< area.beaver_count {
		area.beavers[i].scars = 1
	}
	for _ in 0 ..< 20 {
		area.trips += 1
		testing.expect_value(t, pick_trip_line(&g).kind, Line_Kind.Scarred)
	}
}

// --- Depth: deeper areas are touchier and pay more ---

@(test)
deeper_areas_are_touchier_with_a_floor :: proc(t: ^testing.T) {
	a := Area{beaver_count = 4}
	shallow := area_limit(&a, 0)
	deeper := area_limit(&a, 5)
	deepest := area_limit(&a, 1000)
	testing.expect_value(t, shallow, 4 * PATIENCE_PER_BEAVER)
	testing.expect(t, deeper < shallow, "touchier")
	testing.expect_value(t, deepest, 4 * MIN_PATIENCE_PER_BEAVER)
}

@(test)
deeper_areas_pay_more_and_fractions_carry :: proc(t: ^testing.T) {
	g := new_game()
	move_on(&g)
	for _ in 0 ..< 4 { move_on(&g) } // depth 5: +50%
	testing.expect_value(t, g.current_area, 5)
	testing.expect_value(t, area_pay_percent(5), 150)
	calm(&g)
	start_hunt(&g)
	step(&g, HUNTER_TRIP_MS) // 1.5 pelts: pays 1, carries 0.5
	testing.expect_value(t, g.pelts, 1)
	start_hunt(&g)
	step(&g, HUNTER_TRIP_MS) // 1.5 + 0.5 carried: pays 2
	testing.expect_value(t, g.pelts, 3)
}

@(test)
losing_a_hand_does_not_discount_the_next :: proc(t: ^testing.T) {
	g := new_game()
	g.pelts = 1000
	buy_hand(&g, .Quiet)
	buy_hand(&g, .Quiet)
	price := hand_cost(.Quiet, g.bought[.Quiet])
	g.hands[.Quiet] = 0 // beaten out of them
	testing.expect_value(t, hand_cost(.Quiet, g.bought[.Quiet]), price)
	// A full reset starts a new run at the base price.
	area := cur(&g)
	area.beavers[0].grudge = area_limit(area, g.current_area)
	step(&g, TICK_MS)
	testing.expect_value(t, g.bought[.Quiet], 0)
	testing.expect_value(t, hand_cost(.Quiet, g.bought[.Quiet]), 10)
}

// --- Hunter upgrades ---

@(test)
hunter_upgrades_raise_the_haul_and_cost_more :: proc(t: ^testing.T) {
	testing.expect_value(t, hunter_haul(0), HUNTER_HAUL)
	testing.expect_value(t, hunter_haul(3), HUNTER_HAUL + 3 * HUNTER_HAUL_PER_LEVEL)
	testing.expect_value(t, hunter_upgrade_cost(0), HUNTER_UPGRADE_BASE_COST)
	prev := hunter_upgrade_cost(0)
	for n in 1 ..< 30 {
		c := hunter_upgrade_cost(u64(n))
		testing.expectf(t, c > prev, "cost rises at %d", n)
		prev = c
	}
}

@(test)
hunter_drain_rises_every_second_level :: proc(t: ^testing.T) {
	testing.expect_value(t, hunter_drain(0), HUNTER_DRAIN)
	testing.expect_value(t, hunter_drain(1), HUNTER_DRAIN)
	testing.expect_value(t, hunter_drain(2), HUNTER_DRAIN + 1)
	testing.expect_value(t, hunter_drain(5), HUNTER_DRAIN + 2)
}

@(test)
buying_a_hunter_upgrade_needs_pelts_and_pays_off :: proc(t: ^testing.T) {
	g := new_game()
	g.pelts = HUNTER_UPGRADE_BASE_COST - 1
	testing.expect(t, !buy_hunter_upgrade(&g), "cannot afford")
	testing.expect_value(t, g.hunter_level, 0)
	g.pelts = HUNTER_UPGRADE_BASE_COST
	testing.expect(t, buy_hunter_upgrade(&g), "affords")
	testing.expect_value(t, g.pelts, 0)
	testing.expect_value(t, g.hunter_level, 1)
	start_hunt(&g)
	step(&g, HUNTER_TRIP_MS)
	testing.expect_value(t, g.pelts, hunter_haul(1))
}

@(test)
a_full_reset_clears_the_hunter_level :: proc(t: ^testing.T) {
	g := new_game()
	g.hunter_level = 4
	area := cur(&g)
	area.beavers[0].grudge = area_limit(area, g.current_area)
	step(&g, TICK_MS)
	testing.expect_value(t, g.hunter_level, 0)
}
