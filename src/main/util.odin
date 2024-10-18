package main

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

