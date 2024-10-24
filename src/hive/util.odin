// Functions should only be added to this file if they do not alter state

package hive

import rl "vendor:raylib"
import "core:fmt"
import "core:log"
import "core:math"
import "core:time"
import "core:slice"
import "base:runtime"

GameOutcome :: enum {
    Undecided,
    Tie,
    Elimination,
    Win
}

get_neighbor :: proc(position: [2]int, direction: Direction) -> (neighbor: [2]int, err: bool) {

    direction_vectors: [Direction][2]int
    if position.y % 2 == 0 {
        direction_vectors = Even_Direction_Vectors
    } else {
        direction_vectors = Odd_Direction_Vectors
    }
    vector := direction_vectors[direction]
    neighbor = [2]int{position.x+vector.x, position.y+vector.y}
    err = neighbor.x < 0 || HIVE_X_LENGTH <= neighbor.x ||
          neighbor.y < 0 || HIVE_Y_LENGTH <= neighbor.y
    return neighbor, err
}

get_bug :: proc(position: [2]int, hive := g_hive) -> (bug: Bug) {
    return hive[position.x][position.y]
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
    hexagon := get_hexagon(g_zoom)
    bounds.min = {offset.x-hexagon.width_fraction, offset.y-hexagon.height_fraction}
    bounds.max = {offset.x+hexagon.width_fraction, offset.y+hexagon.height_fraction}
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
    log.assertf(0 <= i_hand && i_hand < HAND_SIZE, "%d", i_hand)
    return g_players[g_player_with_turn].hand[i_hand].hive_position == {-1, -1}
}

lookup_hive_position :: proc(hive_position: [2]int) -> (player_i: int, hand_i: int) {
    log.assertf(0 <= hive_position.x && hive_position.x < HIVE_X_LENGTH, "%d", hive_position.x)
    log.assertf(0 <= hive_position.y && hive_position.y < HIVE_Y_LENGTH, "%d", hive_position.y)
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

get_losers :: proc(hive: [HIVE_X_LENGTH][HIVE_Y_LENGTH]Bug) -> (losers: [PLAYERS]bool) {

    for x in 0..<HIVE_X_LENGTH {
        for y in 0..<HIVE_Y_LENGTH {
            if hive[x][y] != .Queen {
                continue
            }
            queen_surrounded := true
            for direction in Direction {
                neighbor, err := get_neighbor({x, y}, direction)
                if err || hive[neighbor.x][neighbor.y] == .Empty {
                    queen_surrounded = false
                }
            }
            if queen_surrounded {
                player_i, _ := lookup_hive_position({x, y})
                losers[player_i] = true
            }
        }
    }
    return losers
}

get_winners :: proc(hive: [HIVE_X_LENGTH][HIVE_Y_LENGTH]Bug) -> (winners: [PLAYERS]bool) {
    losers := get_losers(hive)
    for i in 0..<PLAYERS {
        winners[i] = !losers[i]
    }
    return winners
}

get_game_outcome :: proc(hive: [HIVE_X_LENGTH][HIVE_Y_LENGTH]Bug) -> (game_outcome: GameOutcome) {
    winners := get_winners(hive)
    winner_count := slice.count(winners[:], true)
    switch winner_count {
    case PLAYERS:
        game_outcome = .Undecided
    case 1:
        game_outcome = .Win
    case 0:
        game_outcome = .Tie
    case:
        game_outcome = .Elimination
    }
    return game_outcome
}

set_hand_bugs :: proc(hand: ^[HAND_SIZE]Piece, bug: Bug, bug_count: int) {
    for i in 0..<HAND_SIZE {
        if hand[i].bug == .Empty {
            for j in 0..<bug_count {
                hand[i+j].bug = bug
            }
            return
        }
    }
}

// See https://pkg.odin-lang.org/core/debug/trace/#Context
report_assertion_failure :: proc(prefix, message: string, loc := #caller_location) -> ! {
    runtime.print_caller_location(loc)
    runtime.print_string(" ")
    runtime.print_string(prefix)
    if len(message) > 0 {
        runtime.print_string(": ")
        runtime.print_string(message)
    }
    runtime.print_byte('\n')
    runtime.trap()
}

