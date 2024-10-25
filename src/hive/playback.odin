package hive

import rl "vendor:raylib"
import "core:fmt"
import "core:log"
import "core:time"
import "core:os"
import "core:strings"
import "core:strconv"
import sa "core:container/small_array"

@(private="file")
g_playback_stopwatch: time.Stopwatch

@(private="file")
g_playback_input := ""

// Caller is responsible for calling close on g_game_file
create_playback_output_file :: proc() -> os.Handle {
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

write_playback_source :: proc(val: int) {
    write_to_playback_output_file("source", val)
}

write_playback_destination :: proc(val: int) {
    write_to_playback_output_file("destination", val)
}

setup_playback :: proc(playback_input_filepath: string) {
    log.debugf("Setting up playback with <%s>", playback_input_filepath)
    data, ok := os.read_entire_file(playback_input_filepath, context.allocator)
    defer delete(data)
    assert(ok)
    data_str := string(data)
    trimmed_data_str := strings.trim(data_str, "\n")
    g_playback_input = strings.clone(trimmed_data_str)
}

playback_line :: proc() -> (finished: bool) {

    if !g_playback_stopwatch.running {
        log.debug("Starting playback stopwatch")
        time.stopwatch_start(&g_playback_stopwatch)
    }

    delay := 500 * time.Millisecond

    if time.stopwatch_duration(g_playback_stopwatch) > delay {
        line, ok := strings.split_lines_iterator(&g_playback_input)
        if !ok {
            return true
        }
        log.debugf("Playing back <%s>", line)
        fields := strings.fields(line)
        assert(len(fields) == 2)

        switch fields[0] {
        case "source":
            g_source = strconv.atoi(fields[1])
        case "destination":
            g_destination = strconv.atoi(fields[1])
        }
        time.stopwatch_reset(&g_playback_stopwatch)
        time.stopwatch_start(&g_playback_stopwatch)
    }
    return false
}

@(private="file")
write_to_playback_output_file :: proc(name: string, value: int) {
    // if g_sim { return }
    os.write_string(g_playback_output_file, fmt.aprintln(name, value))
}

