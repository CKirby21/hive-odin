package hive

import rl "vendor:raylib"
import "core:fmt"
import "core:log"
import "core:time"
import "core:os"
import "core:strings"
import "core:strconv"
import sa "core:container/small_array"

g_playback_stopwatch: time.Stopwatch
g_playback_input := ""

g_playback_output_file: os.Handle

g_sim := false

@(private="file")
sim_mouse: rl.Vector2

@(private="file")
Sim_Mouse_Button_Presses := [rl.MouseButton]bool {
    .LEFT    = false,
    .RIGHT   = false,
    .MIDDLE  = false,
    .SIDE    = false,
    .EXTRA   = false,
    .FORWARD = false,
    .BACK    = false,
}

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

write_to_playback_output_file :: proc(name: string, value: int) {
    // if g_sim { return }
    os.write_string(g_playback_output_file, fmt.aprintln(name, value))
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
    g_playback_input = strings.clone(string(data))
}

// :TODO: take in a string instead of a filepath for sim testing
// Sim testing could pass seed via command line and use GNU parallel or xargs
playback_line :: proc() -> (finished: bool) {

    log.assert(g_playback_input != "", "Must call setup playback first")

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
        if line != "" {
            log.debugf("Playing back <%s>", line)
            fields := strings.fields(line)
            assert(len(fields) == 2)

            switch fields[0] {
            case "source":
                g_source = strconv.atoi(fields[1])
                bounds := g_players[g_player_with_turn].hand[g_source].bounds
                simulate_press(bounds, rl.MouseButton.LEFT)
            case "destination":
                destination := strconv.atoi(fields[1])
                bounds := sa.get(g_placeables, destination).bounds
                simulate_press(bounds, rl.MouseButton.LEFT)
            }
            time.stopwatch_reset(&g_playback_stopwatch)
            time.stopwatch_start(&g_playback_stopwatch)
        }
    }
    return false
}

simulate_press :: proc(bounds: Bounds, mouse_button: rl.MouseButton) {
    sim_mouse = rl.Vector2{
        (bounds.max.x - bounds.min.x) / 2,
        (bounds.max.y - bounds.min.y) / 2,
    }
    Sim_Mouse_Button_Presses[mouse_button] = true
}

get_simulated_mouse :: proc(mouse_button: rl.MouseButton) -> (pressed: bool, mouse: rl.Vector2) {
    pressed = Sim_Mouse_Button_Presses[mouse_button]
    Sim_Mouse_Button_Presses[mouse_button] = false
    mouse = sim_mouse
    return pressed, mouse
}

