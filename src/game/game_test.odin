#+build !js
package game

import "core:testing"

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
	testing.expect_value(t, hand_cost(.Quiet, g.hands[.Quiet]), 12)
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
	big, small := new_game(), new_game()
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
	testing.expect_value(t, big.hand_ms, small.hand_ms)
}

@(test)
catch_up_is_capped :: proc(t: ^testing.T) {
	g := new_game()
	g.hands[.Quiet] = 1
	counted := catch_up(&g, 24 * 60 * 60 * 1000)
	testing.expect_value(t, counted, OFFLINE_CAP_MS)
	testing.expect_value(t, g.elapsed_ms, OFFLINE_CAP_MS)
	testing.expect_value(t, g.pelts, (OFFLINE_CAP_MS / HAND_DEFS[.Quiet].trip_ms) * HAND_DEFS[.Quiet].haul)
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
