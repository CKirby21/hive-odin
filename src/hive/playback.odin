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
    os.write_string(playback_file, fmt.aprintln("source", "target.x", "target.y"))
    log.assertf(err == os.ERROR_NONE, "Failed to open <%s", playback_filename)
    return playback_file
}

playback_game :: proc(playback_filepath: string) {
    init_game()

    Turn :: struct {
        source: int,
        target: [2]int,
    }

    data, ok := os.read_entire_file(playback_filepath, context.allocator)
    defer delete(data)
    assert(ok)

    turns: [dynamic]Turn
    defer delete(turns)

    it := string(data)
    log.debugf("Parsing playback file <%s>...", playback_filepath)
    for line in strings.split_lines_iterator(&it) {
        if line == "" { continue }
        fields := strings.fields(line)
        assert(len(fields) == 3)
        if fields[0] == "source" {
            assert(fields[1] == "target.x")
            assert(fields[2] == "target.y")
            continue
        }
        source := strconv.atoi(fields[0])
        target := [2]int{
            strconv.atoi(fields[1]),
            strconv.atoi(fields[2]),
        }
        append(&turns, Turn { source, target })
    }

    turn := 0
    stopwatch: time.Stopwatch
    time.stopwatch_start(&stopwatch)
    delay := 1000 * time.Millisecond
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


