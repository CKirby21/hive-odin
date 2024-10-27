package tests

import h "../src"
import "core:testing"
import "core:fmt"
import sa "core:container/small_array"

add_piece :: proc(hive: ^h.Hive, piece: h.Piece) {
    stack := &hive[piece.hive_position.x][piece.hive_position.y]
    sa.append(stack, piece)
}

@(test)
test_hive_whole :: proc(t: ^testing.T) {
    hive: h.Hive
    sa.append(&hive[5][5], h.new_piece(bug=.Queen))
    sa.append(&hive[5][6], h.new_piece(bug=.Ant))
    testing.expect(t, h.validate_hive(hive))
}

@(test)
test_hive_broken :: proc(t: ^testing.T) {
    hive: h.Hive
    sa.append(&hive[5][5], h.new_piece(bug=.Queen))
    sa.append(&hive[5][9], h.new_piece(bug=.Ant))
    testing.expect(t, !h.validate_hive(hive))
}

@(test)
test_undecided :: proc(t: ^testing.T) {
    hive: h.Hive
    add_piece(&hive, h.new_piece(bug=.Queen, player_i=0, hive_position={5, 5}))
    add_piece(&hive, h.new_piece(bug=.Ant,   player_i=0, hive_position={5, 3})) // North
    add_piece(&hive, h.new_piece(bug=.Ant,   player_i=0, hive_position={6, 4})) // Northeast
    add_piece(&hive, h.new_piece(bug=.Ant,   player_i=0, hive_position={6, 6})) // Southeast
    add_piece(&hive, h.new_piece(bug=.Ant,   player_i=0, hive_position={5, 7})) // South
    add_piece(&hive, h.new_piece(bug=.Ant,   player_i=0, hive_position={5, 6})) // Southwest
    game_outcome := h.get_game_outcome(hive)
    testing.expectf(t, game_outcome == h.GameOutcome.Undecided, "%s", game_outcome)
}

@(test)
test_win :: proc(t: ^testing.T) {
    hive: h.Hive
    add_piece(&hive, h.new_piece(bug=.Queen, player_i=0, hive_position={5, 5}))
    add_piece(&hive, h.new_piece(bug=.Ant,   player_i=0, hive_position={5, 3})) // North
    add_piece(&hive, h.new_piece(bug=.Ant,   player_i=0, hive_position={6, 4})) // Northeast
    add_piece(&hive, h.new_piece(bug=.Ant,   player_i=0, hive_position={6, 6})) // Southeast
    add_piece(&hive, h.new_piece(bug=.Ant,   player_i=0, hive_position={5, 7})) // South
    add_piece(&hive, h.new_piece(bug=.Ant,   player_i=0, hive_position={5, 6})) // Southwest
    add_piece(&hive, h.new_piece(bug=.Ant,   player_i=0, hive_position={5, 4})) // Northwest
    game_outcome := h.get_game_outcome(hive)
    testing.expectf(t, game_outcome == h.GameOutcome.Win, "%s", game_outcome)
}

@(test)
test_tie :: proc(t: ^testing.T) {
    hive: h.Hive
    add_piece(&hive, h.new_piece(bug=.Queen, player_i=0, hive_position={5, 5}))
    add_piece(&hive, h.new_piece(bug=.Ant,   player_i=1, hive_position={5, 3})) // North
    add_piece(&hive, h.new_piece(bug=.Ant,   player_i=0, hive_position={6, 4})) // Northeast
    add_piece(&hive, h.new_piece(bug=.Ant,   player_i=1, hive_position={6, 6})) // Southeast
    add_piece(&hive, h.new_piece(bug=.Ant,   player_i=0, hive_position={5, 6})) // Southwest
    add_piece(&hive, h.new_piece(bug=.Ant,   player_i=1, hive_position={5, 4})) // Northwest

    add_piece(&hive, h.new_piece(bug=.Queen, player_i=1, hive_position={5, 7}))
    add_piece(&hive, h.new_piece(bug=.Ant,   player_i=0, hive_position={6, 6})) // Northeast
    add_piece(&hive, h.new_piece(bug=.Ant,   player_i=1, hive_position={6, 8})) // Southeast
    add_piece(&hive, h.new_piece(bug=.Ant,   player_i=0, hive_position={5, 9})) // South
    add_piece(&hive, h.new_piece(bug=.Ant,   player_i=1, hive_position={5, 8})) // Southwest
    add_piece(&hive, h.new_piece(bug=.Ant,   player_i=0, hive_position={5, 6})) // Northwest
    game_outcome := h.get_game_outcome(hive)
    testing.expectf(t, game_outcome == h.GameOutcome.Tie, "%s", game_outcome)
}
