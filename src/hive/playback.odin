package hive

import rl "vendor:raylib"
import "core:fmt"
import "core:log"
import "core:time"
import "core:os"
import sa "core:container/small_array"

// Creates a game file that can be played back later
// 
// Caller is responsible for calling close on g_game_file
create_game_file :: proc() {
    mode: int = 0
	when ODIN_OS == .Linux || ODIN_OS == .Darwin {
		mode = os.S_IRUSR | os.S_IWUSR | os.S_IRGRP | os.S_IROTH
	}
    game_filename := fmt.aprintf("game_%s.txt", get_iso8601_timestamp())
    log.debugf("Capuring game file <%s> for later playback", game_filename)
    g_game_file, err := os.open(game_filename, (os.O_CREATE | os.O_TRUNC | os.O_RDWR), mode)
    log.assertf(err == os.ERROR_NONE, "Failed to open <%s", game_filename)
}

playback_game :: proc(game_filename: string) {
    init_game()

    Turn :: struct {
        source: int,
        target: [2]int,
    }

    // :TODO: Save and read in game log as turns
    turn := 0
    turns := [?]Turn{
        {2, {3, 10}},
        {2, {3, 11}},
    }
    stopwatch: time.Stopwatch
    time.stopwatch_start(&stopwatch)
    delay := 2000 * time.Millisecond
    log.debugf("Playback starting with a delay of %.0f ms between states...", time.duration_milliseconds(delay))

    for !rl.WindowShouldClose() {
        if time.stopwatch_duration(stopwatch) > delay {
            if turn >= len(turns) {
                break
            }
            log.debug("Playing back turn <%d>", turn)
            g_source = turns[turn].source
            place_piece(turns[turn].target)
            turn += 1
            time.stopwatch_reset(&stopwatch)
            time.stopwatch_start(&stopwatch)
        }
        update_game()
        draw_game()
    }
    log.debug("Finished playback.")
}


