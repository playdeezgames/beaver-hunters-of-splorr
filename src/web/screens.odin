// Drawing: title, play and credits screens, and the clickable buttons they register.
#+build js
package main

import "core:fmt"
import game "tggd:game"

Button :: struct {
	x, y, w, h: i32,
	action:     Action,
	enabled:    bool,
}

buttons: [16]Button
button_count: int

// Urizen tiles picked for the scene: (column, row).
Tile_Art :: [2]i32
TREES :: [?]Tile_Art{{0, 8}, {1, 8}, {2, 8}, {3, 8}, {4, 8}}
TUFTS :: [?]Tile_Art{{3, 9}, {4, 9}, {6, 9}, {10, 9}}
WATER :: Tile_Art{15, 6}
HUNTER :: Tile_Art{104, 0}
HAND_QUIET :: Tile_Art{104, 4}
HAND_STRONG :: Tile_Art{105, 5}
BEAVER :: Tile_Art{4, 14}

SCENE_X :: i32(16)
SCENE_Y :: i32(40)
SCENE_COLS :: i32(14)
SCENE_ROWS :: i32(7)
PANEL_X :: i32(368)

draw :: proc() {
	fill_rect(0, 0, SCREEN_W, SCREEN_H, PAPER)
	button_count = 0
	switch screen {
	case .Title:
		draw_title()
	case .Play:
		draw_play()
	case .Credits:
		draw_credits()
	}
}

// --- Primitives ---

draw_tile :: proc(t: Tile_Art, x, y: i32) {
	sx := (TILE + TILE_GAP) * t.x + TILE_GAP
	sy := (TILE + TILE_GAP) * t.y + TILE_GAP
	blit_raw(i32(Sheet.Urizen), sx, sy, TILE, TILE, x, y, CELL, CELL)
}

// DINOBYTE: a 16 by 16 sheet of 6 by 8 cells in code page 437 order.
draw_text :: proc(s: string, x, y: i32, rgb: u32 = INK, scale: i32 = SCALE) {
	cx := x
	for i in 0 ..< len(s) {
		c := i32(s[i])
		blit(i32(Sheet.Font), (c % 16) * GLYPH_W, (c / 16) * GLYPH_H, GLYPH_W, GLYPH_H, cx, y, GLYPH_W * scale, GLYPH_H * scale, rgb)
		cx += GLYPH_W * scale
	}
}

text_width :: proc(s: string, scale: i32 = SCALE) -> i32 {
	return i32(len(s)) * GLYPH_W * scale
}

draw_centered :: proc(s: string, y: i32, rgb: u32 = INK, scale: i32 = SCALE) {
	draw_text(s, (SCREEN_W - text_width(s, scale)) / 2, y, rgb, scale)
}

draw_frame :: proc(x, y, w, h: i32, rgb: u32) {
	fill_rect(x, y, w, 2, rgb)
	fill_rect(x, y + h - 2, w, 2, rgb)
	fill_rect(x, y, 2, h, rgb)
	fill_rect(x + w - 2, y, 2, h, rgb)
}

draw_button :: proc(label: string, x, y, w: i32, action: Action, enabled: bool) {
	h: i32 = 24
	colour: u32 = INK if enabled else DIM
	draw_frame(x, y, w, h, colour)
	draw_text(label, x + 8, y + 4, colour)
	if button_count < len(buttons) {
		buttons[button_count] = {x, y, w, h, action, enabled}
		button_count += 1
	}
}

draw_bar :: proc(x, y, w: i32, num, den: u64, rgb: u32) {
	h: i32 = 8
	draw_frame(x, y, w, h + 4, DIM)
	if den > 0 {
		fill_w := i32(u64(w - 4) * min(num, den) / den)
		fill_rect(x + 2, y + 2, fill_w, h, rgb)
	}
}

// A small deterministic hash for scattering scenery.
hash :: proc(a, b, c: u64) -> u64 {
	h := a * 0x9E3779B97F4A7C15 ~ b * 0xBF58476D1CE4E5B9 ~ c * 0x94D049BB133111EB
	h = (h ~ (h >> 29)) * 0xD6E8FEB86659FD93
	return h ~ (h >> 32)
}

// Trees, grass and a little water scattered over the rows above and below the actors.
draw_scenery :: proc(seed: u64, x0, y0: i32, cols, rows: i32) {
	trees := TREES
	tufts := TUFTS
	for r in 0 ..< rows {
		if r >= 3 && r <= 5 && rows == SCENE_ROWS {
			continue // the actors' band
		}
		for c in 0 ..< cols {
			h := hash(seed, u64(c), u64(r))
			x := x0 + c * CELL
			y := y0 + r * CELL
			switch h % 20 {
			case 0, 1, 2:
				draw_tile(trees[(h >> 8) % u64(len(trees))], x, y)
			case 3, 4, 5, 6:
				draw_tile(tufts[(h >> 8) % u64(len(tufts))], x, y)
			case 7:
				draw_tile(WATER, x, y)
			}
		}
	}
}

// --- Screens ---

draw_title :: proc() {
	draw_scenery(0xB3A7E5, 0, 0, SCREEN_W / CELL + 1, SCREEN_H / CELL + 1)
	// Clear a band behind the words so they stay readable.
	fill_rect(0, 56, SCREEN_W, 250, PAPER)
	draw_tile(HUNTER, SCREEN_W / 2 - CELL / 2, 28)
	draw_centered("BEAVER HUNTERS", 76, INK, 4)
	draw_centered("OF SPLORR!!", 116, ACCENT, 4)

	if confirm_erase {
		draw_centered("Erase yer save? This cannot be undone.", 190, WARN)
		draw_button("[Y] Erase", 200, 226, 108, .Confirm_Erase, true)
		draw_button("[N] Keep", 332, 226, 108, .Cancel_Erase, true)
		return
	}
	label := "[Enter] Continue" if have_save else "[Enter] Play"
	draw_button(label, 200, 180, 240, .Play, true)
	draw_button("[C] Credits", 200, 214, 240, .Credits, true)
	if have_save {
		draw_button("[X] Erase save", 200, 248, 240, .Erase, true)
	}
}

draw_credits :: proc() {
	lines := [?]string {
		"CREDITS",
		"",
		"Tiles: Urizen 1-bit tileset by vurmux",
		"https://vurmux.itch.io/urizen-onebit-tileset",
		"CC0 1.0",
		"",
		"Font: DINOBYTE bitmap font by mby",
		"https://mby.itch.io/dinobyte",
		"CC BY 4.0",
		"",
		"Written with Claude Code (AI-assisted).",
	}
	y: i32 = 24
	for l in lines {
		colour: u32 = ACCENT if l == "CREDITS" else INK
		draw_centered(l, y, colour)
		y += 24
	}
	draw_button("[Esc] Back", 220, 308, 200, .Title, true)
}

draw_play :: proc() {
	g := &state
	area := &g.areas[g.current_area]

	// Header.
	area_name := game.AREA_NAMES[area.name]
	draw_text(area_name, SCENE_X, 12, ACCENT)
	buf: [64]u8
	draw_text(fmt.bprintf(buf[:], "Area %d/%d", g.current_area + 1, g.area_count), SCENE_X + 220, 12, DIM)

	// Scene.
	draw_frame(SCENE_X - 4, SCENE_Y - 4, SCENE_COLS * CELL + 8, SCENE_ROWS * CELL + 8, DIM)
	draw_scenery(u64(area.name) * 1000 + u64(g.current_area), SCENE_X, SCENE_Y, SCENE_COLS, SCENE_ROWS)
	actor_y := SCENE_Y + 4 * CELL
	draw_tile(HUNTER, SCENE_X + CELL, actor_y)
	hand_x := SCENE_X + 3 * CELL
	shown := 0
	for kind in game.Hand_Kind {
		art := HAND_QUIET if kind == .Quiet else HAND_STRONG
		for _ in 0 ..< min(g.hands[kind], 5) {
			if shown >= 4 {
				break
			}
			draw_tile(art, hand_x + i32(shown) * CELL, actor_y)
			shown += 1
		}
	}
	for i in 0 ..< area.beaver_count {
		draw_tile(BEAVER, SCENE_X + (i32(i) * 2 + 4) * CELL, actor_y + CELL)
	}

	// Beavers, with a mark for each scar.
	draw_text("Beavers", SCENE_X, 232, DIM)
	for i in 0 ..< area.beaver_count {
		b := area.beavers[i]
		marks := min(int(b.scars), 3)
		col := i32(i % 3)
		row := i32(i / 3)
		x := SCENE_X + col * 112
		y := 254 + row * 20
		draw_text(game.BEAVER_NAMES[b.name], x, y)
		for m in 0 ..< marks {
			draw_text("*", x + text_width(game.BEAVER_NAMES[b.name]) + 4 + i32(m) * 12, y, WARN)
		}
	}

	// Panel.
	px: i32 = PANEL_X
	bar_x := px + 168
	draw_text(fmt.bprintf(buf[:], "Pelts %d", g.pelts), px, 12)
	buf4: [32]u8
	draw_text(fmt.bprintf(buf4[:], "Hunter +%d", game.hunter_haul(g.hunter_level)), px, 40, DIM)
	draw_bar(bar_x, 42, 96, g.hunter_ms if g.hunter_out else 0, game.HUNTER_TRIP_MS, ACCENT)
	hunt_label := "[H] Hunting..." if g.hunter_out else "[H] Hunt"
	draw_button(hunt_label, px, 64, 264, .Hunt, !g.hunter_out)

	train_cost := game.hunter_upgrade_cost(g.hunter_level)
	buf5: [32]u8
	draw_button(fmt.bprintf(buf5[:], "[T] Train  %d", train_cost), px, 92, 264, .Train, g.pelts >= train_cost)

	y: i32 = 126
	for kind in game.Hand_Kind {
		def := game.HAND_DEFS[kind]
		count := g.hands[kind]
		cost := game.hand_cost(kind, g.bought[kind])
		buf2: [64]u8
		draw_text(fmt.bprintf(buf2[:], "%s x%d", def.name, count), px, y, DIM)
		draw_bar(bar_x, y + 2, 96, g.hand_ms[kind] if count > 0 else 0, def.trip_ms, ACCENT)
		key := "S" if kind == .Quiet else "R"
		action := Action.Hire_Quiet if kind == .Quiet else Action.Hire_Strong
		buf3: [64]u8
		draw_button(fmt.bprintf(buf3[:], "[%s] Hire  %d", key, cost), px, y + 20, 264, action, g.pelts >= cost)
		y += 52
	}
	draw_button("[M] Move on", px, y, 264, .Move_On, true)
	draw_button("[<]", px, y + 30, 126, .Prev_Area, g.current_area > 0)
	draw_button("[>]", px + 138, y + 30, 126, .Next_Area, g.current_area + 1 < g.area_count)
	draw_button("[Esc] Title", px, y + 60, 264, .Title, true)

	// Message lines: below both columns, clear of the panel (which ends at about y 314).
	draw_wrapped(message, SCENE_X, 322, 52)
}

// Breaks `s` at spaces into at most two lines of `width` characters.
draw_wrapped :: proc(s: string, x, y: i32, width: int) {
	rest := s
	for line in 0 ..< 2 {
		if len(rest) == 0 {
			return
		}
		n := len(rest)
		if n > width {
			n = width
			for n > 0 && rest[n] != ' ' {
				n -= 1
			}
			if n == 0 {
				n = width
			}
		}
		draw_text(rest[:n], x, y + i32(line) * 20)
		rest = rest[n:]
		for len(rest) > 0 && rest[0] == ' ' {
			rest = rest[1:]
		}
	}
}
