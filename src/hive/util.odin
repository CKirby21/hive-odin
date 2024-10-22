// Functions should only be added to this file if they do not alter state

package hive

import rl "vendor:raylib"
import "core:fmt"
import "core:log"
import "core:math"
import "core:time"

get_neighbor :: proc(position: [2]int, direction: Direction) -> ([2]int, bool) {

    direction_vectors: [Direction][2]int
    if position.y % 2 == 0 {
        direction_vectors = Even_Direction_Vectors
    } else {
        direction_vectors = Odd_Direction_Vectors
    }
    vector := direction_vectors[direction]
    neighbor := [2]int{position.x+vector.x, position.y+vector.y}
    err := neighbor.x < 0 || HIVE_X_LENGTH <= neighbor.x || 
          neighbor.y < 0 || HIVE_Y_LENGTH <= neighbor.y
    return neighbor, err
}

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
    assert_index(i_hand, HAND_SIZE)
    return g_players[g_player_with_turn].hand[i_hand].hive_position == {-1, -1}
}

lookup_hive_position :: proc(hive_position: [2]int) -> (int, int) {
    assert_index(hive_position.x, HIVE_X_LENGTH)
    assert_index(hive_position.y, HIVE_Y_LENGTH)
    log.assert(g_hive[hive_position.x][hive_position.y] != .Empty)

    i := -1
    for j in 0..<PLAYERS {
        for i in 0..<HAND_SIZE {
            if g_players[j].hand[i].hive_position == hive_position {
                return j, i
            }
        }
    }

    fmt.panicf("Hive position <%d %d> should have been found", hive_position.x, hive_position.y)
}

can_play :: proc() -> bool {
    play := false
    for piece, i in g_players[g_player_with_turn].hand {
        err: bool
        if is_in_hand(i) {
            err = populate_places()
        } else {
            err = populate_moves(i)
        }
        if !err {
            play = true
        }
    }
    return play
}

