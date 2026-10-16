// Browser platform layer: canvas shim, clock, storage, input and the frame loop.
// JS loads the sheets and tints them at draw time; Odin only says what to draw.
#+build js
package main

import "base:runtime"
import "core:fmt"
import "core:sys/wasm/js"
import "core:time"
import "core:math/rand"
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
	// Wall clock in milliseconds since the epoch.
	now_ms :: proc() -> f64 ---
	// localStorage. get copies the value into buf and returns its length, or -1 if absent.
	storage_get :: proc(key: [^]u8, key_len: i32, buf: [^]u8, cap: i32) -> i32 ---
	storage_set :: proc(key: [^]u8, key_len: i32, val: [^]u8, val_len: i32) ---
	storage_remove :: proc(key: [^]u8, key_len: i32) ---
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
CELL :: TILE * SCALE // 24 px on screen

PAPER :: 0x101418
INK :: 0xe8dcb0
DIM :: 0x6a6450
ACCENT :: 0xd08040
WARN :: 0xe05040

SAVE_KEY: string : "bhos:save" // every itch.io html5 game shares one localStorage origin
AUTOSAVE_MS :: 5_000
AWAY_NOTICE_MS :: 60_000 // say something about time away only past a minute

Screen :: enum {
	Title,
	Play,
	Credits,
}

ctx: runtime.Context
state: game.Game
screen: Screen
have_save: bool
confirm_erase: bool
last_ms: f64
last_save_ms: f64
message_buf: [160]u8
message: string

main :: proc() {
	ctx = context
	rand.reset(u64(time.now()._nsec))
	state = game.new_game(u64(now_ms()))
	load_save()
	js.add_window_event_listener(.Key_Down, nil, on_key)
}

load_save :: proc() {
	buf: [game.SAVE_BYTES]u8
	n := storage_get(raw_data(SAVE_KEY), i32(len(SAVE_KEY)), raw_data(buf[:]), i32(len(buf)))
	if n < 0 {
		return
	}
	loaded, saved_at, ok := game.load_from_bytes(buf[:n])
	if !ok {
		return
	}
	state = loaded
	have_save = true
	away := u64(max(now_ms() - f64(saved_at), 0))
	counted := game.catch_up(&state, away)
	after_step()
	if counted >= AWAY_NOTICE_MS && state.last_beating.beatings == 0 {
		set_message(fmt.bprintf(message_buf[:], "You were away %d minutes.", counted / 60_000))
	}
}

save :: proc() {
	buf: [game.SAVE_BYTES]u8
	n := game.save_to_bytes(&state, u64(now_ms()), buf[:])
	if n > 0 {
		storage_set(raw_data(SAVE_KEY), i32(len(SAVE_KEY)), raw_data(buf[:]), i32(n))
		have_save = true
	}
	last_save_ms = now_ms()
}

erase_save :: proc() {
	storage_remove(raw_data(SAVE_KEY), i32(len(SAVE_KEY)))
	state = game.new_game(u64(now_ms()))
	have_save = false
	set_message("")
}

set_message :: proc(s: string) {
	// `s` may already live in message_buf; copy through a temp so it is never aliased.
	tmp: [len(message_buf)]u8
	n := copy(tmp[:], s)
	copy(message_buf[:], tmp[:n])
	message = string(message_buf[:n])
}

@(export)
step :: proc(dt: f64, c: runtime.Context) -> bool {
	context = ctx
	now := now_ms()
	if last_ms == 0 {
		last_ms = now
	}
	delta := u64(max(now - last_ms, 0))
	last_ms = now
	if delta > 2_000 { // the tab was away: treat it as offline time (capped)
		counted := game.catch_up(&state, delta)
		after_step()
		if counted >= AWAY_NOTICE_MS && state.last_beating.beatings == 0 {
			set_message(fmt.bprintf(message_buf[:], "You were away %d minutes.", counted / 60_000))
		}
	} else {
		game.step(&state, delta)
		after_step()
	}
	if screen == .Play && now - last_save_ms >= AUTOSAVE_MS {
		save()
	}
	draw()
	free_all(context.temp_allocator)
	return true
}

// Turns what just happened into the message line, and saves when it matters.
after_step :: proc() {
	if state.last_beating.beatings > 0 {
		set_beating_message()
		save()
	} else if state.last_hunter.trips > 0 {
		set_trip_message()
	}
}

set_trip_message :: proc() {
	line := game.pick_trip_line(&state)
	area := &state.areas[state.current_area]
	switch line.kind {
	case .Plain:
		set_message(game.TRIP_LINES[line.index])
	case .Named:
		name := game.BEAVER_NAMES[area.beavers[line.beaver].name]
		set_message(fmt.bprintf(message_buf[:], "%s %s", name, game.NAMED_FRAGMENTS[line.index]))
	case .Scarred:
		name := game.BEAVER_NAMES[area.beavers[line.beaver].name]
		set_message(fmt.bprintf(message_buf[:], "%s %s", name, game.SCARRED_FRAGMENTS[line.index]))
	}
}

// PLACEHOLDER wording; the user writes the real lines.
set_beating_message :: proc() {
	b := state.last_beating
	area_name := game.AREA_NAMES[state.areas[state.current_area].name]
	lost := b.hands_lost[.Quiet] + b.hands_lost[.Strong]
	if b.resets > 0 {
		name := game.BEAVER_NAMES[state.areas[b.scar_area].beavers[b.scar_beaver].name]
		set_message(fmt.bprintf(message_buf[:], "The beavers of %s gang up. Nobody is left to stand between. %s makes a mark.", area_name, name))
	} else {
		set_message(fmt.bprintf(message_buf[:], "The beavers of %s gang up. %d hands are lost.", area_name, lost))
	}
}

// --- Input ---

Action :: enum {
	None,
	Play,
	Credits,
	Title,
	Erase,
	Confirm_Erase,
	Cancel_Erase,
	Hunt,
	Hire_Quiet,
	Hire_Strong,
	Move_On,
	Prev_Area,
	Next_Area,
}

do_action :: proc(a: Action) {
	switch a {
	case .None:
	case .Play:
		screen = .Play
	case .Credits:
		screen = .Credits
	case .Title:
		screen = .Title
		confirm_erase = false
		save()
	case .Erase:
		confirm_erase = true
	case .Confirm_Erase:
		erase_save()
		confirm_erase = false
	case .Cancel_Erase:
		confirm_erase = false
	case .Hunt:
		game.start_hunt(&state)
	case .Hire_Quiet:
		if game.buy_hand(&state, .Quiet) {
			save()
		}
	case .Hire_Strong:
		if game.buy_hand(&state, .Strong) {
			save()
		}
	case .Move_On:
		game.move_on(&state)
		save()
	case .Prev_Area:
		game.go_to_area(&state, state.current_area - 1)
	case .Next_Area:
		game.go_to_area(&state, state.current_area + 1)
	}
}

on_key :: proc(e: js.Event) {
	context = ctx
	a := key_action(e.data.key.code)
	if a != .None {
		js.event_prevent_default()
		do_action(a)
	}
}

key_action :: proc(code: string) -> Action {
	switch screen {
	case .Title:
		if confirm_erase {
			switch code {
			case "KeyY": return .Confirm_Erase
			case "KeyN", "Escape": return .Cancel_Erase
			}
			return .None
		}
		switch code {
		case "Enter", "Space": return .Play
		case "KeyC": return .Credits
		case "KeyX": return .Erase
		}
	case .Play:
		switch code {
		case "KeyH", "Space": return .Hunt
		case "KeyQ": return .Hire_Quiet
		case "KeyS": return .Hire_Strong
		case "KeyM": return .Move_On
		case "ArrowLeft": return .Prev_Area
		case "ArrowRight": return .Next_Area
		case "Escape": return .Title
		}
	case .Credits:
		switch code {
		case "Escape", "Enter", "Space": return .Title
		}
	}
	return .None
}

// Called by the page for a click or tap, in logical (640 by 360) pixels.
@(export)
on_click :: proc "c" (x, y: i32) {
	context = ctx
	for i in 0 ..< button_count {
		b := buttons[i]
		if b.enabled && x >= b.x && x < b.x + b.w && y >= b.y && y < b.y + b.h {
			do_action(b.action)
			return
		}
	}
}
