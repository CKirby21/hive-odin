// Functions should only be added to this file if they are small and have no side effects

package hive

import rl "vendor:raylib"
import "core:fmt"
import "core:log"
import "core:math"
import "core:time"

get_iso8601_timestamp :: proc() -> string {
    now := time.now()
    hms_buf: [time.MIN_HMS_LEN + 1]u8
    hms := time.time_to_string_hms(now, hms_buf[:])
    yyyy_mm_dd_buf: [time.MIN_YYYY_DATE_LEN + 1]u8
    yyyy_mm_dd := time.to_string_yyyy_mm_dd(now, yyyy_mm_dd_buf[:])
    return fmt.aprintf("%sT%s", yyyy_mm_dd, hms)

}

get_occupied_positions :: proc(hive: [HIVE_X_LENGTH][HIVE_Y_LENGTH]Bug) -> (occupied_positions: int) {
    for x in 0..<HIVE_X_LENGTH {
        for y in 0..<HIVE_Y_LENGTH {
            if hive[x][y] != .Empty {
                occupied_positions += 1
            }
        }
    }
    return occupied_positions
}

update_bounds :: proc(bounds: ^Bounds, offset: rl.Vector2) {
    bounds.min = {offset.x-HEXAGON_WIDTH_FRACTION, offset.y-HEXAGON_HEIGHT_FRACTION}
    bounds.max = {offset.x+HEXAGON_WIDTH_FRACTION, offset.y+HEXAGON_HEIGHT_FRACTION}
}

assert_index :: proc(index: int, max: int) {
    log.assertf(0 <= index && index <= max, "0 <= %d <= %d", index, max)
}

within_bounds :: proc(bounds: Bounds, position: rl.Vector2) -> (within: bool) {
    return bounds.min.x <= position.x && position.x <= bounds.max.x && 
           bounds.min.y <= position.y && position.y <= bounds.max.y
}

get_start :: proc() -> (start: [2]int) {
    start.x = HIVE_X_LENGTH / 2
    start.y = HIVE_Y_LENGTH / 2
    return start
}

is_in_hand :: proc(i_hand: int) -> bool {
    return g_players[g_player_with_turn].hand[i_hand].hive_position == {-1, -1}
}

