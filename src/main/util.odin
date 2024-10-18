// Functions should only be added to this file if they are small and pure

package main

import rl "vendor:raylib"
import "core:fmt"
import "core:log"
import "core:math"

// get_len :: proc(array: [$N]$T) {
get_len :: proc(array: [$N][2]int) -> int {
    for i := N - 1; i >= 0; i -= 1 {
        if array[i] != {-1, -1} {
            return i + 1
        }
    }
    panic("Uhhhh")
}

exists :: proc(array: [$N][2]int, value: [2]int) -> bool {
    for i in 0..<N {
        if array[i] == value {
            return true
        }
    }
    return false
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

within_bounds :: proc(bounds: Bounds, position: rl.Vector2) -> (within: bool) {
    return bounds.min.x <= position.x && position.x <= bounds.max.x && 
           bounds.min.y <= position.y && position.y <= bounds.max.y
}

get_start :: proc() -> (start: [2]int) {
    start.x = HIVE_X_LENGTH / 2
    start.y = HIVE_Y_LENGTH / 2
    return start
}

