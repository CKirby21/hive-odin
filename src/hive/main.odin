package hive

import rl "vendor:raylib"
import "core:math"
import "core:fmt"
import "core:log"
import "core:time"
import "core:os"
import "core:slice"
import sa "core:container/small_array"

SCREEN_WIDTH  :: 900
SCREEN_HEIGHT :: 940
SCREEN_PADDING_X :: 50
SCREEN_PADDING_Y :: 50

FONT_SIZE :: 12
FONT_SPACING :: 1
FONT: rl.Font

PLAYERS :: 2
g_players: [PLAYERS]Player
g_player_with_turn: int // Index into the g_players array
HAND_SIZE :: 11
g_source: int // Index into the player with turn's hand

HIVE_X_LENGTH    :: 7
HIVE_Y_LENGTH      :: 20 
g_hive:           [HIVE_X_LENGTH][HIVE_Y_LENGTH]Bug
g_placeables: sa.Small_Array(HAND_SIZE * PLAYERS * 6, Piece)

g_game_file: os.Handle

Bug_Colors := [Bug]rl.Color {
    .Empty       = rl.WHITE,
    .Queen       = rl.YELLOW,
    .Ant         = rl.DARKBLUE,
    .Grasshopper = rl.LIME,
    .Spider      = rl.RED,
    .Beetle      = rl.BLUE,
}

Even_Direction_Vectors := [Direction][2]int {
    // .None      = {  0,  0 },
    .North     = {  0, -2 },
    .Northeast = {  0, -1 },
    .Southeast = {  0,  1 },
    .South     = {  0,  2 },
    .Southwest = { -1,  1 },
    .Northwest = { -1, -1 },
}

// North and South do not change depeding on y, every other direction does
Odd_Direction_Vectors := [Direction][2]int {
    // .None      = {  0,  0 },
    .North     = Even_Direction_Vectors[.North],
    .Northeast = {  1, -1 },
    .Southeast = {  1,  1 },
    .South     = Even_Direction_Vectors[.South],
    .Southwest = {  0,  1 },
    .Northwest = {  0, -1 },
}

// Opposite_Directions := [Direction]Direction {
//     .None      = .None,
//     .North     = .South,
//     .Northeast = .Southwest,
//     .Southeast = .Northwest,
//     .South     = .North,
//     .Southwest = .Northeast,
//     .Northwest = .Southeast,
// }

Bounds :: struct {
    min: rl.Vector2,
    max: rl.Vector2,
}

Player :: struct {
    hand: [HAND_SIZE]Piece,
    color: rl.Color
}

Bug :: enum {
    Empty, // Zero Value
    Queen,
    Ant,
    Grasshopper,
    Spider,
    Beetle,
}

Direction :: enum {
    // None, // Zero Value
    North,
    Northeast,
    Southeast,
    South,
    Southwest,
    Northwest
}

Piece :: struct {
    bug: Bug,
    bounds: Bounds,
    hive_position: [2]int,
}

Logger_Opts :: log.Options{
	.Level,
	.Terminal_Color,
	.Short_File_Path,
	.Line,
}

main :: proc() {
    logger := log.create_console_logger(log.Level.Debug, Logger_Opts)
    context.logger = logger
    defer log.destroy_console_logger(logger)

    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Hive")
    defer rl.CloseWindow()   
    
    FONT = rl.GetFontDefault()
    rl.SetTargetFPS(60)

    create_game_file()

    if len(os.args) == 1 {
        init_game()
        for !rl.WindowShouldClose() { // Detect window close button or ESC key
            update_game()
            draw_game()
        }
    } else {
        assert(len(os.args) == 2)
        assert(len(os.args) == 2)
        playback_game(os.args[1])
    }
    os.close(g_game_file)
}

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

// Creates a game file that can be played back later
// 
// Caller is responsible for calling close on g_game_file
create_game_file :: proc() {
    mode: int = 0
	when ODIN_OS == .Linux || ODIN_OS == .Darwin {
		mode = os.S_IRUSR | os.S_IWUSR | os.S_IRGRP | os.S_IROTH
	}
    game_filename := fmt.aprintf("game_%s.txt", get_iso8601_timestamp())
    log.debugf("Capuring game file <%s> for later playback", game_filename)
    g_game_file, err := os.open(game_filename, (os.O_CREATE | os.O_TRUNC | os.O_RDWR), mode)
    assert(err == os.ERROR_NONE)
}

playback_game :: proc(game_filename: string) {
    init_game()

    Turn :: struct {
        source: int,
        target: [2]int,
    }

    // :TODO: Save and read in game log as turns
    turn := 0
    turns := [?]Turn{
        {2, {3, 10}},
        {2, {3, 11}},
    }
    stopwatch: time.Stopwatch
    time.stopwatch_start(&stopwatch)
    delay := 2000 * time.Millisecond
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


init_game :: proc() {

    log.debug("Initializing state...")

    // Init Players
    assert(len(g_players) == PLAYERS)
    g_players = {}
    for i in 0..<PLAYERS {
        bounds := Bounds{ rl.Vector2{-1,-1}, rl.Vector2{-1,-1} }
        bug := Bug.Empty
        hive_position := [2]int{-1,-1}
        piece := Piece{ bug, bounds, hive_position }
        for j in 0..<HAND_SIZE {
            g_players[i].hand[j] = piece
        }
        g_players[i].hand[0].bug = .Queen
        g_players[i].hand[1].bug = .Ant
        g_players[i].hand[2].bug = .Ant
        g_players[i].hand[3].bug = .Ant
        g_players[i].hand[4].bug = .Grasshopper
        g_players[i].hand[5].bug = .Grasshopper
        g_players[i].hand[6].bug = .Grasshopper
        g_players[i].hand[7].bug = .Spider
        g_players[i].hand[8].bug = .Spider
        g_players[i].hand[9].bug = .Beetle
        g_players[i].hand[10].bug = .Beetle
    }
    g_player_with_turn = 0

    // Assign player colors
    assert(len(g_players) == 2)
    g_players[0].color = rl.BEIGE
    g_players[1].color = rl.BLACK

    // Init Hive
    assert(len(g_hive) == HIVE_X_LENGTH)
    g_hive = {}
    for i in 0..<HIVE_X_LENGTH {
        for j in 0..<HIVE_Y_LENGTH {
            g_hive[i][j] = .Empty
        }
    }

    sa.clear(&g_placeables)
    g_source = -1

    log.debug("Finished initializing state.")
}

update_game :: proc() {

    if rl.IsMouseButtonPressed(rl.MouseButton.LEFT) {
        mouse := rl.GetMousePosition()
        for player, i in g_players {
            for piece, j in player.hand {
                if within_bounds(piece.bounds, mouse) && i == g_player_with_turn {
                    log.debugf("Selected a <%s> from Player <%d> at hand_i <%d>\n", piece.bug, i, j)
                    
                    err: bool 
                    if is_in_hand(j) {
                        err = populate_places()
                    } else {
                        err = populate_moves(j)
                    }
                    if err {
                        // :TODO: handle when there is nowhere to place/move
                        assert(false)
                    }
                    g_source = j
                }
            }
        }
        for i in 0..<sa.len(g_placeables) {
            piece := sa.get(g_placeables, i)
            if within_bounds(piece.bounds, mouse) {
                assert_index(g_source, HAND_SIZE)
                place_piece(piece.hive_position)
            }
        }
    }
}

// Validates that the hive is not broken, meaning that every bug 
// is attached to at least one other bug
//
// Caller is responsible for asserting that the return value is true
validate_hive :: proc(hive: [HIVE_X_LENGTH][HIVE_Y_LENGTH]Bug) -> (valid_hive: bool) {

    valid_hive = true

    occupied := get_occupied_positions(hive)
    if occupied <= 1 {
        return true
    }
    neighbors: sa.Small_Array(HAND_SIZE * PLAYERS, [2]int)

    out:
    for x in 0..<HIVE_X_LENGTH {
        for y in 0..<HIVE_Y_LENGTH {
            if hive[x][y] != .Empty {
                sa.append(&neighbors, [2]int{x, y})
                break out
            }
        }
    }

    for i in 0..<occupied {
        position, ok := sa.get_safe(neighbors, i)
        if !ok {
            break
        }
        for direction in Direction {
            neighbor, err := get_neighbor(position, direction)
            if err || hive[neighbor.x][neighbor.y] == .Empty {
                continue
            }
            // log.debug("Neighbor:", neighbor, err, direction, hive[neighbor.x][neighbor.y])
            if !slice.contains(sa.slice(&neighbors), neighbor) {
                sa.append(&neighbors, neighbor)
            }
        }
    }

    if sa.len(neighbors) != occupied {
        valid_hive = false
    }

    return valid_hive
}

populate_moves :: proc(i_hand: int) -> (err: bool) {

    log.assert(!is_in_hand(i_hand),
        "Function should only be called if piece is already placed in the hive")

    sa.clear(&g_placeables)

    // This is so that the current position does not contribute to the logic below
    piece := g_players[g_player_with_turn].hand[i_hand]
    hive := g_hive
    hive[piece.hive_position.x][piece.hive_position.y] = .Empty

    // Check if moving would break the hive
    if !validate_hive(hive) {
        err = true
        return err
    }

    for x in 0..<HIVE_X_LENGTH {
        for y in 0..<HIVE_Y_LENGTH {

            position := [2]int{x, y}
            neighbors := 0
            for direction in Direction {
                neighbor, err := get_neighbor(position, direction)
                if err {
                    continue
                }
                if hive[neighbor.x][neighbor.y] != .Empty {
                    neighbors += 1
                }
            }

            // Add new piece
            if 0 < neighbors && neighbors <= 4 && position != piece.hive_position {
                placeable_piece := Piece{}
                placeable_piece.hive_position = position
                sa.append(&g_placeables, placeable_piece)
            }
        }
    }

    if sa.len(g_placeables) == 0 {
        err = true
    }

    return err
}

populate_places :: proc() -> (err: bool) {

    sa.clear(&g_placeables)

    placeable_piece := Piece{}
    occupied := get_occupied_positions(g_hive) 
    if occupied == 0 {
        placeable_piece.hive_position = get_start()
        sa.append(&g_placeables, placeable_piece)
        return false
    }
    else if occupied == 1 {
        for direction in Direction {
            neighbor, err := get_neighbor(get_start(), direction)
            assert(!err)
            placeable_piece.hive_position = neighbor
            sa.append(&g_placeables, placeable_piece)
        }
        return false
    }

    for x in 0..<HIVE_X_LENGTH {
        for y in 0..<HIVE_Y_LENGTH {

            friendlies := 0
            enemies := 0
            position := [2]int{x, y}
            for direction in Direction {
                neighbor, err := get_neighbor(position, direction)
                if err {
                    continue
                }
                if g_hive[neighbor.x][neighbor.y] == .Empty {
                    continue
                }
                player_i, _ := lookup_hive_position(neighbor)
                if player_i == g_player_with_turn {
                    friendlies += 1
                } else {
                    enemies += 1
                }
            }

            if friendlies > 0 && enemies == 0 {
                placeable_piece.hive_position = position
                sa.append(&g_placeables, placeable_piece)
            }
        }
    }


    if sa.len(g_placeables) == 0 {
        err = true
    }

    return err
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

advance_turn :: proc() {
    assert_index(g_player_with_turn, PLAYERS)
    g_player_with_turn += 1
    g_player_with_turn %= PLAYERS // Wrap around
    // fmt.printfln("Player <%d>'s turn", g_player_with_turn)
    assert_index(g_player_with_turn, PLAYERS)
}

place_piece :: proc(hive_position: [2]int) {
    assert_index(g_source, HAND_SIZE)
    assert_index(hive_position.x, HIVE_X_LENGTH)
    assert_index(hive_position.y, HIVE_Y_LENGTH)
    assert(g_hive[hive_position.x][hive_position.y] == .Empty)
    assert(validate_hive(g_hive))

    bug := g_players[g_player_with_turn].hand[g_source].bug
    g_hive[hive_position.x][hive_position.y] = bug
    g_players[g_player_with_turn].hand[g_source].hive_position = hive_position
    log.debugf("Player <%d> placed <%s> at <%d %d>", g_player_with_turn, bug, hive_position.x, hive_position.y)
    g_source = -1
    sa.clear(&g_placeables)

    advance_turn()

    // :TODO: Skip players that can't play. Infinite loop?
    // for !can_play() {
    //     advance_turn()
    // }

    assert(validate_hive(g_hive))
}

should_highlight :: proc(hive_position: [2]int, offset: rl.Vector2) -> (highlight: bool) {
    for i in 0..<sa.len(g_placeables) {
        piece := sa.get(g_placeables, i)
        if piece.hive_position == hive_position {
            update_bounds(&piece.bounds, offset) // :FIX: Not sure if i like this here
            sa.set(&g_placeables, i, piece)
            highlight = true
        }
    }
    return highlight
}

lookup_hive_position :: proc(hive_position: [2]int) -> (int, int) {
    assert_index(hive_position.x, HIVE_X_LENGTH)
    assert_index(hive_position.y, HIVE_Y_LENGTH)

    i := -1
    for j in 0..<PLAYERS {
        for i in 0..<HAND_SIZE {
            if g_players[j].hand[i].hive_position == hive_position {
                return j, i
            }
        }
    }

    panic("Hive position should have been found. Was the lookup array not populated?")
}

