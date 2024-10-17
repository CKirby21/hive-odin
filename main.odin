package main

import rl "vendor:raylib"
import "core:math"
import "core:fmt"
import "core:log"
import "core:time"

HEXAGON_SIDES :: 6
HEXAGON_RADIUS: f32 = 40.0
HEXAGON_ANGLE: f32 = 2.0 * math.PI / HEXAGON_SIDES
HEXAGON_WIDTH: f32 = HEXAGON_RADIUS * 2
HEXAGON_HEIGHT: f32 = HEXAGON_RADIUS * math.SQRT_THREE
HEXAGON_WIDTH_FRACTION: f32 = HEXAGON_WIDTH / 2.7
HEXAGON_HEIGHT_FRACTION: f32 = HEXAGON_HEIGHT / 2

SCREEN_WIDTH  :: 900
SCREEN_HEIGHT :: 940
SCREEN_PADDING_X :: 50
SCREEN_PADDING_Y :: 50

SPACING_X :: 0
SPACING_Y :: 5 

FONT_SIZE :: 12
FONT_SPACING :: 1
FONT: rl.Font

PLAYERS :: 2
players: [PLAYERS]Player
player_with_turn: int // Index into the players array
HAND_SIZE :: 11
selection_i: int // Index into the player with turn's hand

HIVE_X_LENGTH    :: 7
HIVE_Y_LENGTH      :: 16
g_hive:           [HIVE_X_LENGTH][HIVE_Y_LENGTH]Bug
placeable_pieces: [HAND_SIZE * PLAYERS]Piece

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

main :: proc() {
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Hive")
    defer rl.CloseWindow()   
    
    FONT = rl.GetFontDefault()
    rl.SetTargetFPS(60)

    // simulate_game()

    init_game()
    for !rl.WindowShouldClose() { // Detect window close button or ESC key
        update_game()
        draw_game()
    }
}

get_neighbor_position :: proc(position: [2]int, direction: Direction) -> ([2]int, bool) {

    direction_vectors: [Direction][2]int
    if position.y % 2 == 0 {
        direction_vectors = Even_Direction_Vectors
    } else {
        direction_vectors = Odd_Direction_Vectors
    }
    vector := direction_vectors[direction]
    neighbor_position := [2]int{position.x+vector.x, position.y+vector.y}
    err := neighbor_position.x < 0 || HIVE_X_LENGTH <= neighbor_position.x || 
          neighbor_position.y < 0 || HIVE_Y_LENGTH <= neighbor_position.y
    return neighbor_position, err
}

simulate_game :: proc() {
    delay := 2000 * time.Millisecond
    fmt.printfln("Simulation starting with a delay of %f ms between states...", time.duration_milliseconds(delay))

    init_game()

    state := 0
    positions: [100][2]int
    stopwatch: time.Stopwatch
    time.stopwatch_start(&stopwatch)
    // TODO Save and read in game log

    for !rl.IsMouseButtonPressed(rl.MouseButton.RIGHT) {
        if rl.WindowShouldClose() {
            fmt.println("Closed during simulation")
            break
        }

        if time.stopwatch_duration(stopwatch) > delay {
            err := false
            switch state {
            case 0:
                positions[state] = get_start_position()
                // TODO select bug and show where it can go
                place_bug(positions[state], .Grasshopper)
            case 1:
                positions[state], err = get_neighbor_position(positions[0], .Northeast)
                place_bug(positions[state], .Grasshopper)
            case 2:
                positions[state], err = get_neighbor_position(positions[0], .Southwest)
                place_bug(positions[state], .Grasshopper)
            }
            assert(!err)
            state += 1
            time.stopwatch_reset(&stopwatch)
            time.stopwatch_start(&stopwatch)
        }
        update_game()
        draw_game()
    }
    fmt.println("Finished simulation.")
}


init_game :: proc() {

    fmt.println("Initializing state...")

    // Init Players
    assert(len(players) == PLAYERS)
    players = {}
    for i in 0..<PLAYERS {
        bounds := Bounds{ rl.Vector2{-1,-1}, rl.Vector2{-1,-1} }
        bug := Bug.Empty
        hive_position := [2]int{-1,-1}
        piece := Piece{ bug, bounds, hive_position }
        for j in 0..<HAND_SIZE {
            players[i].hand[j] = piece
        }
        players[i].hand[0].bug = .Queen
        players[i].hand[1].bug = .Ant
        players[i].hand[2].bug = .Ant
        players[i].hand[3].bug = .Ant
        players[i].hand[4].bug = .Grasshopper
        players[i].hand[5].bug = .Grasshopper
        players[i].hand[6].bug = .Grasshopper
        players[i].hand[7].bug = .Spider
        players[i].hand[8].bug = .Spider
        players[i].hand[9].bug = .Beetle
        players[i].hand[10].bug = .Beetle
    }
    player_with_turn = 0

    // Assign player colors
    assert(len(players) == 2)
    players[0].color = rl.BEIGE
    players[1].color = rl.BLACK

    // Init Hive
    assert(len(g_hive) == HIVE_X_LENGTH)
    g_hive = {}
    for i in 0..<HIVE_X_LENGTH {
        for j in 0..<HIVE_Y_LENGTH {
            g_hive[i][j] = .Empty
        }
    }

    init_placeable_pieces()
    selection_i = -1

    fmt.println("Finished initializing state.")
}

update_game :: proc() {

    if rl.IsMouseButtonPressed(rl.MouseButton.LEFT) {
        mouse := rl.GetMousePosition()
        for player, i in players {
            for piece, j in player.hand {
                if within_bounds(piece.bounds, mouse) && i == player_with_turn {
                    fmt.printf("Selected a <%s> from Player <%d> at hand_i <%d>\n", piece.bug, i, j)
                    
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
                    selection_i = j
                }
            }
        }
        for piece in placeable_pieces {
            if within_bounds(piece.bounds, mouse) {
                assert(selection_i != -1)
                place_piece(piece.hive_position, selection_i)
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
        return valid_hive
    }
    neighbor_positions: [HAND_SIZE * PLAYERS][2]int
    for &position in neighbor_positions {
        position = {-1, -1}
    }

    start := [2]int{-1, -1}
    for x in 0..<HIVE_X_LENGTH {
        for y in 0..<HIVE_Y_LENGTH {
            if hive[x][y] != .Empty {
                start = {x, y}
            }
        }
    }
    positions_i: int
    neighbor_positions[positions_i] = start
    positions_i += 1

    for i in 0..<occupied {
        position := neighbor_positions[i]
        if position.x == -1 || position.y == -1 {
            valid_hive = false
            break
        }
        for direction in Direction {
            neighbor_position, err := get_neighbor_position(position, direction)
            if err {
                continue
            }
            // fmt.println("Neighbor:", neighbor_position, err, direction, hive[neighbor_position.x][neighbor_position.y])
            if hive[neighbor_position.x][neighbor_position.y] == .Empty {
                continue
            }
            already_added := false
            for j in 0..<occupied {
                if neighbor_position == neighbor_positions[j] {
                    already_added = true
                }
            }
            if !already_added {
                neighbor_positions[positions_i] = neighbor_position
                positions_i += 1
            }
        }
    }

    fmt.println(neighbor_positions)
    log.assertf(positions_i == occupied, "%d %d", positions_i, occupied)

    return valid_hive
}

init_placeable_pieces :: proc() {
    placeable_pieces = [HAND_SIZE * PLAYERS]Piece{}
    for &piece in placeable_pieces {
        piece.hive_position = {-1, -1}
    }
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

populate_moves :: proc(i_hand: int) -> (err: bool) {

    log.assert(!is_in_hand(i_hand),
        "Function should only be called if piece is already placed in the hive")

    init_placeable_pieces()
    pieces_i: int

    // This is so that the current position does not contribute to the logic below
    piece := players[player_with_turn].hand[i_hand]
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
                neighbor_position, err := get_neighbor_position(position, direction)
                if err {
                    continue
                }
                if hive[neighbor_position.x][neighbor_position.y] != .Empty {
                    neighbors += 1
                }
            }

            // Add new piece
            if 0 < neighbors && neighbors <= 4 && position != piece.hive_position {
                placeable_pieces[pieces_i].hive_position = position
                pieces_i += 1
            }
        }
    }

    if placeable_pieces[0].hive_position == {-1, -1} {
        err = true
    }

    return err
}

is_in_hand :: proc(i_hand: int) -> bool {
    return players[player_with_turn].hand[i_hand].hive_position == {-1, -1}
}

populate_places :: proc() -> (err: bool) {

    init_placeable_pieces()
    pieces_i: int

    for x in 0..<HIVE_X_LENGTH {
        for y in 0..<HIVE_Y_LENGTH {

            friendlies := 0
            enemies := 0
            position := [2]int{x, y}
            for direction in Direction {
                neighbor_position, err := get_neighbor_position(position, direction)
                if err {
                    continue
                }
                if g_hive[neighbor_position.x][neighbor_position.y] == .Empty {
                    continue
                }
                player_i, _ := lookup_hive_position(neighbor_position)
                if player_i == player_with_turn {
                    friendlies += 1
                } else {
                    enemies += 1
                }
            }

            if friendlies > 0 && enemies == 0 {
                placeable_pieces[pieces_i].hive_position = position
                pieces_i += 1
            }
        }
    }

    if get_occupied_positions(g_hive) == 0 {
        placeable_pieces[0].hive_position = get_start_position()
    }
    else if get_occupied_positions(g_hive) == 1 {
        for direction in Direction {
            neighbor_position, err := get_neighbor_position(get_start_position(), direction)
            assert(!err)
            placeable_pieces[pieces_i].hive_position = neighbor_position
            pieces_i += 1
        }
    }

    if placeable_pieces[0].hive_position == {-1, -1} {
        err = true
    }

    return err
}

within_bounds :: proc(bounds: Bounds, position: rl.Vector2) -> (within: bool) {
    return bounds.min.x <= position.x && position.x <= bounds.max.x && 
           bounds.min.y <= position.y && position.y <= bounds.max.y
}

get_start_position :: proc() -> (start_position: [2]int) {
    start_position.x = HIVE_X_LENGTH / 2
    start_position.y = HIVE_Y_LENGTH / 2
    return start_position
}

can_play :: proc() -> bool {
    play := false
    for piece, i in players[player_with_turn].hand {
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
    init_placeable_pieces()
    return play
}

advance_turn :: proc() {
    assert(0 <= player_with_turn && player_with_turn < PLAYERS)
    player_with_turn += 1
    player_with_turn %= PLAYERS // Wrap around
    // fmt.printfln("Player <%d>'s turn", player_with_turn)
    assert(0 <= player_with_turn && player_with_turn < PLAYERS)
}

// Used for simulation
place_bug :: proc(hive_position: [2]int, bug: Bug) {
    i_hand := -1
    for piece, i in players[player_with_turn].hand {
        if piece.bug == bug && piece.hive_position == {-1, -1} {
            i_hand = i
            break
        }
    }
    log.assertf(i_hand != -1, "Did not find a %s in player %d's hand", bug, player_with_turn)
    place_piece(hive_position, i_hand)
}

// :TODO: Remove i_hand and use global selection_i
place_piece :: proc(hive_position: [2]int, i_hand: int) {
    assert(0 <= i_hand          && i_hand          < HAND_SIZE)
    assert(0 <= hive_position.x && hive_position.x < HIVE_X_LENGTH)
    assert(0 <= hive_position.y && hive_position.y < HIVE_Y_LENGTH)
    assert(g_hive[hive_position.x][hive_position.y] == .Empty)
    assert(validate_hive(g_hive))

    bug := players[player_with_turn].hand[i_hand].bug
    g_hive[hive_position.x][hive_position.y] = bug
    players[player_with_turn].hand[i_hand].hive_position = hive_position
    fmt.printfln("Player <%d> placed <%s> at <%d %d>", player_with_turn, bug, hive_position.x, hive_position.y)
    selection_i = -1
    advance_turn()

    // Skip players that can't play. Infinite loop?
    // for !can_play() {
    //     advance_turn()
    // }
    init_placeable_pieces()

    assert(validate_hive(g_hive))
}

update_bounds :: proc(bounds: ^Bounds, offset: rl.Vector2) {
    bounds.min = {offset.x-HEXAGON_WIDTH_FRACTION, offset.y-HEXAGON_HEIGHT_FRACTION}
    bounds.max = {offset.x+HEXAGON_WIDTH_FRACTION, offset.y+HEXAGON_HEIGHT_FRACTION}
}

should_highlight :: proc(hive_position: [2]int, offset: rl.Vector2) -> (highlight: bool) {
    for &piece in placeable_pieces {
        if piece.hive_position == hive_position {
            update_bounds(&piece.bounds, offset) // :FIX: Not sure if i like this here
            highlight = true
        }
    }
    return highlight
}

lookup_hive_position :: proc(hive_position: [2]int) -> (int, int) {
    log.assert(hive_position.x >= 0)
    log.assert(hive_position.y >= 0)

    i := -1
    for j in 0..<PLAYERS {
        for i in 0..<HAND_SIZE {
            if players[j].hand[i].hive_position == hive_position {
                return j, i
            }
        }
    }

    panic("Hive position should have been found. Was the lookup array not populated?")
}

draw_piece :: proc(offset: rl.Vector2, player_i: int, hand_i: int) {
    bug := players[player_i].hand[hand_i].bug
    log.assert(bug != .Empty, "Shouldn't be drawing an empty bug")

    rl.DrawPoly(offset, HEXAGON_SIDES, HEXAGON_RADIUS, 0, players[player_i].color)
    rl.DrawPolyLinesEx(offset, HEXAGON_SIDES, HEXAGON_RADIUS, 0, 1, rl.BLACK)

    // Draw text inside piece
    text := rl.TextFormat("%s", bug)
    text_size := rl.MeasureTextEx(FONT, text, FONT_SIZE, FONT_SPACING)
    text_offset: rl.Vector2 = {offset.x-(text_size.x/2), offset.y-(text_size.y/2)}
    rl.DrawTextEx(FONT, text, text_offset, FONT_SIZE, FONT_SPACING, Bug_Colors[bug])

    update_bounds(&players[player_i].hand[hand_i].bounds, offset)
}

draw_game :: proc() {
    rl.BeginDrawing()
    defer rl.EndDrawing()

    rl.ClearBackground(rl.RAYWHITE)


    offset := rl.Vector2 {
        SCREEN_PADDING_X,
        SCREEN_PADDING_Y,
    }

    controller := offset.x

    // Draw da hive
    for y in 0..<HIVE_Y_LENGTH {
        offset.x = controller + (f32(y % 2) * HEXAGON_RADIUS * 1.5)
        // fmt.println(j, rotate, width, height)
        for x in 0..<HIVE_X_LENGTH {
            if g_hive[x][y] == .Empty {
                if should_highlight({x, y}, offset) {
                    rl.DrawPolyLinesEx(offset, HEXAGON_SIDES, HEXAGON_RADIUS, 0, 3, rl.BLUE)
                } else {
                    rl.DrawPolyLinesEx(offset, HEXAGON_SIDES, HEXAGON_RADIUS, 0, 1, rl.GRAY)
                }
                rl.DrawTextEx(FONT, rl.TextFormat("%i %i", x, y), offset, FONT_SIZE, 2, rl.GRAY)
            }
            else {
                player_i, hand_i := lookup_hive_position({x, y})
                draw_piece(offset, player_i, hand_i)
            }
            offset.x += 3 * HEXAGON_RADIUS
        }

        offset.y += HEXAGON_HEIGHT / 2
    }

    // Add some spacing between the hive and the player hands
    offset.y += 120

    // Draw bugs in each player's hand
    for player, i in players {
        offset.x = controller
        for piece, j in player.hand {

            // Go to next line if bugs don't fit
            if offset.x > SCREEN_WIDTH - SCREEN_PADDING_X {
                offset.x = controller
                offset.y += HEXAGON_HEIGHT + SPACING_Y
            }

            if piece.hive_position == {-1, -1} {
                draw_piece(offset, i, j)
            }
            else {
                // Don't draw bugs that are no longer in the player's hand
            }
            offset.x += HEXAGON_WIDTH + SPACING_X

        }
        offset.y += HEXAGON_HEIGHT + SPACING_Y
    }

}


