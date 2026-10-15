// Pure rules: no platform imports, so it tests natively with `odin test`.
package game

Game :: struct {
	elapsed_ms: u64,
}

new_game :: proc() -> Game {
	return Game{}
}

// Advances the simulation by `dt_ms` of wall-clock time.
step :: proc(g: ^Game, dt_ms: u64) {
	g.elapsed_ms += dt_ms
}
