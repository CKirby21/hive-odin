package hive

import rl "vendor:raylib"
import "core:fmt"
import "core:log"
import "core:time"
import "core:os"
import "core:strings"
import "core:strconv"
import sa "core:container/small_array"

// Caller is responsible for calling close on g_game_file
create_playback_file :: proc() -> os.Handle {
    mode: int = 0
	when ODIN_OS == .Linux || ODIN_OS == .Darwin {
		mode = os.S_IRUSR | os.S_IWUSR | os.S_IRGRP | os.S_IROTH
	}
    playback_filename := fmt.aprintf("playback_%s.txt", get_iso8601_timestamp())
    log.debugf("Capuring game file <%s> for later playback", playback_filename)
    playback_file, err := os.open(playback_filename, (os.O_CREATE | os.O_TRUNC | os.O_RDWR), mode)
    log.assertf(err == os.ERROR_NONE, "Failed to open <%s", playback_filename)
    return playback_file
}

playback_game :: proc(playback_filepath: string) {
    init_game()

    data, ok := os.read_entire_file(playback_filepath, context.allocator)
    defer delete(data)
    assert(ok)
    data_string := string(data)


    stopwatch: time.Stopwatch
    time.stopwatch_start(&stopwatch)
    delay := 500 * time.Millisecond
    log.debugf("Playback starting with a delay of %.0f ms between lines...", time.duration_milliseconds(delay))

    for !rl.WindowShouldClose() {
        if time.stopwatch_duration(stopwatch) > delay {
            line, ok := strings.split_lines_iterator(&data_string)
            if !ok {
                break
            }
            if line == "" {
                continue
            }
            log.debugf("Playing back <%s>", line)
            fields := strings.fields(line)
            assert(len(fields) == 2)

            switch fields[0] {
            case "source":
                // :FIXME: Theres gotta be a better way to not duplicate this
                // Maybe populate_places should return a placeables array instead of 
                // modifying the global?
                reset_turn_variables()
                g_source = strconv.atoi(fields[1])
                piece := g_players[g_player_with_turn].hand[g_source]
                if is_in_hand(g_source) {
                    populate_places()
                } else if is_move_allowed(piece) {
                    populate_moves(g_source)
                }
            case "destination":
                destination := strconv.atoi(fields[1])
                place_piece(g_source, destination)
            }
            time.stopwatch_reset(&stopwatch)
            time.stopwatch_start(&stopwatch)
        }
        update_game()
        draw_game()
    }
    log.debug("Finished playback.")
}


