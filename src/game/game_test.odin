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
