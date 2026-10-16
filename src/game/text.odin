// Which trip line to show. Pure and deterministic, so it tests natively; the web layer formats it.
package game

Line_Kind :: enum {
	Plain, // TRIP_LINES[index]
	Named, // beaver name + NAMED_FRAGMENTS[index]
	Scarred, // beaver name + SCARRED_FRAGMENTS[index]
}

Trip_Line :: struct {
	kind:   Line_Kind,
	index:  int,
	beaver: int, // index in the current area; meaningful for Named and Scarred
}

// A scarred beaver that took the last trip always gets a line that acknowledges the scar.
pick_trip_line :: proc(g: ^Game) -> Trip_Line {
	area := &g.areas[g.current_area]
	count := u64(area.beaver_count)
	last := (area.trips + count - 1) % count // the beaver that took the latest trip (round-robin)
	n := area.trips + u64(g.current_area) * 7 + g.beatings
	line := Trip_Line {
		beaver = int(last),
	}
	if area.beavers[last].scars > 0 {
		line.kind = .Scarred
		line.index = int(n % len(SCARRED_FRAGMENTS))
	} else if n % 3 == 0 {
		line.kind = .Named
		line.index = int((n / 3) % len(NAMED_FRAGMENTS))
	} else {
		line.kind = .Plain
		line.index = int(n % len(TRIP_LINES))
	}
	return line
}
