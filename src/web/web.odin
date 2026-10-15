// Browser platform layer: canvas shim, input and the frame loop.
// JS loads the sheets and tints them at draw time; Odin only says what to draw.
#+build js
package main

import "base:runtime"
import "core:math/rand"
import "core:time"
import game "tggd:game"

foreign import canvas "canvas"

@(default_calling_convention = "contextless")
foreign canvas {
	// Fill a rectangle in logical pixels with 0xRRGGBB.
	fill_rect :: proc(x, y, w, h: i32, rgb: u32) ---
	// Copy a w by h piece of a sheet at (sx, sy) to (dx, dy), scaled to dw by dh, tinted 0xRRGGBB.
	blit :: proc(sheet: i32, sx, sy, w, h: i32, dx, dy, dw, dh: i32, rgb: u32) ---
	// Same, with the sheet's own colours (Urizen tiles carry their colour).
	blit_raw :: proc(sheet: i32, sx, sy, w, h: i32, dx, dy, dw, dh: i32) ---
}

// Order matches `files` in web/index.html.
Sheet :: enum i32 {
	Urizen,
	Font,
}

SCREEN_W :: 640
SCREEN_H :: 360
TILE :: 12 // Urizen native tile size
TILE_GAP :: 1
SCALE :: 2 // tiles and font are both drawn at 2x so they share a pixel size
GLYPH_W :: 6
GLYPH_H :: 8

PAPER :: 0x101418
INK :: 0xe8dcb0

ctx: runtime.Context
state: game.Game

main :: proc() {
	ctx = context
	rand.reset(u64(time.now()._nsec))
	state = game.new_game(u64(time.now()._nsec))
}

@(export)
step :: proc(dt: f64, c: runtime.Context) -> bool {
	context = ctx
	game.step(&state, u64(dt * 1000))
	draw()
	free_all(context.temp_allocator)
	return true
}

draw :: proc() {
	fill_rect(0, 0, SCREEN_W, SCREEN_H, PAPER)
	draw_text("BEAVER HUNTERS OF SPLORR!!", 16, 16, INK)
	draw_text("m0 scaffold", 16, 40, INK)
	// A strip of Urizen tiles from the environment section, to prove the sheet and knockout work.
	for col in 0 ..< 26 {
		draw_tile(i32(col), 2, 16 + i32(col) * TILE * SCALE, 80)
	}
}

draw_tile :: proc(col, row: i32, x, y: i32) {
	sx := (TILE + TILE_GAP) * col + TILE_GAP
	sy := (TILE + TILE_GAP) * row + TILE_GAP
	blit_raw(i32(Sheet.Urizen), sx, sy, TILE, TILE, x, y, TILE * SCALE, TILE * SCALE)
}

// DINOBYTE: a 16 by 16 sheet of 6 by 8 cells in code page 437 order.
draw_text :: proc(s: string, x, y: i32, rgb: u32) {
	cx := x
	for i in 0 ..< len(s) {
		c := i32(s[i])
		blit(i32(Sheet.Font), (c % 16) * GLYPH_W, (c / 16) * GLYPH_H, GLYPH_W, GLYPH_H, cx, y, GLYPH_W * SCALE, GLYPH_H * SCALE, rgb)
		cx += GLYPH_W * SCALE
	}
}
