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
hive:           [HIVE_X_LENGTH][HIVE_Y_LENGTH]Bug
place_positions: [HAND_SIZE * PLAYERS][2]int

Bug_Colors := [Bug]rl.Color {
    .Queen       = rl.YELLOW,
    .Ant         = rl.DARKBLUE,
    .Grasshopper = rl.LIME,
    .Spider      = rl.RED,
    .Beetle      = rl.BLUE,
    .Empty       = rl.WHITE,
}

Even_Direction_Vectors := [Direction][2]int {
    .North     = {  0, -2 },
    .Northeast = {  0, -1 },
    .Southeast = {  0,  1 },
    .South     = {  0,  2 },
    .Southwest = { -1,  1 },
    .Northwest = { -1, -1 },
}

// North and South do not change depeding on y, every other direction does
Odd_Direction_Vectors := [Direction][2]int {
    .North     = Even_Direction_Vectors[.North],
    .Northeast = { -1, -1 },
    .Southeast = {  1, -1 },
    .South     = Even_Direction_Vectors[.South],
    .Southwest = {  0,  1 },
    .Northwest = {  0, -1 },
}

Bounds :: struct {
    min: rl.Vector2,
    max: rl.Vector2,
}

Player :: struct {
    hand: [HAND_SIZE]Piece,
    color: rl.Color
}

Bug :: enum {
    Queen,
    Ant,
    Grasshopper,
    Spider,
    Beetle,
    Empty
}

Direction :: enum {
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

    simulate_game()

    init_game()
    for !rl.WindowShouldClose() { // Detect window close button or ESC key
        update_game()
        draw_game()
    }
}

simulate_game :: proc() {
    delay := 2000 * time.Millisecond
    fmt.printfln("Simulation starting with a delay of %f ms between states...", time.duration_milliseconds(delay))

    init_game()

    state := 0
    stopwatch: time.Stopwatch
    time.stopwatch_start(&stopwatch)

    for !rl.IsMouseButtonPressed(rl.MouseButton.RIGHT) {
        if rl.WindowShouldClose() {
            fmt.println("Closed during simulation")
            break
        }

        if time.stopwatch_duration(stopwatch) > delay {
            switch state {
            case 0:
                place_bug({3, 7}, .Grasshopper)
            case 1:
                place_bug({3, 8}, .Grasshopper)
            case 2:
                place_bug({4, 8}, .Queen)
            case 3:
                place_bug({2, 9}, .Queen)
            }
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
    assert(len(hive) == HIVE_X_LENGTH)
    hive = {}
    for i in 0..<HIVE_X_LENGTH {
        for j in 0..<HIVE_Y_LENGTH {
            hive[i][j] = .Empty
        }
    }

    fmt.println("Finished initializing state.")
}

update_game :: proc() {

    if rl.IsMouseButtonPressed(rl.MouseButton.LEFT) {
        position := rl.GetMousePosition()
        for player, i in players {
            for piece, j in player.hand {
                if within_bounds(piece.bounds, position) && i == player_with_turn {
                    fmt.printf("Selected a %s from player_i %d at hand_i %d\n", piece.bug, i, j)
                    selection_i = j
                }
            }
        }
    }
}


// Validates that the hive is not broken, meaning that every bug 
// is attached to at least one other bug
//
// Caller is responsible for asserting that the return value is true
validate_hive :: proc() -> (valid_hive: bool) {
    valid_hive = true
    occupied_positions := 0

    for x in 0..<HIVE_X_LENGTH {
        for y in 0..<HIVE_Y_LENGTH {
            if hive[x][y] == .Empty {
                continue
            } else {
                occupied_positions += 1
            }

            direction_vectors: [Direction][2]int
            if y % 2 == 0 {
                direction_vectors = Even_Direction_Vectors
            } else {
                direction_vectors = Odd_Direction_Vectors
            }

            valid_xy := false
            for direction in Direction {
                vector := direction_vectors[direction]
                position := [2]int{x+vector.x, y+vector.y}
                if position.x < 0 || HIVE_X_LENGTH <= position.x ||
                   position.y < 0 || HIVE_Y_LENGTH <= position.y {
                    continue
                }
                // fmt.println(x, y, "checks for neighbor at", position)
                if hive[position.x][position.y] != .Empty {
                    valid_xy = true
                }
            }

            if !valid_xy {
                valid_hive = false
            }
        }
    }

    if occupied_positions <= 1 {
        valid_hive = true
    }

    return valid_hive
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

advance_turn :: proc() {
    assert(0 <= player_with_turn && player_with_turn < PLAYERS)
    player_with_turn += 1
    player_with_turn %= PLAYERS // Wrap around
    fmt.printfln("Player %d's turn", player_with_turn)
    assert(0 <= player_with_turn && player_with_turn < PLAYERS)
}

// Used for simulation
place_bug :: proc(hive_position: [2]int, bug: Bug) {
    i_hand := -1
    for piece, i in players[player_with_turn].hand {
        if piece.bug == bug {
            i_hand = i
            break
        }
    }
    log.assertf(i_hand != -1, "Did not find a %s in player %d's hand", bug, player_with_turn)
    place_piece(hive_position, i_hand)
}

place_piece :: proc(hive_position: [2]int, i_hand: int) {
    assert(0 <= i_hand          && i_hand          < HAND_SIZE)
    assert(0 <= hive_position.x && hive_position.x < HIVE_X_LENGTH)
    assert(0 <= hive_position.y && hive_position.y < HIVE_Y_LENGTH)
    assert(players[player_with_turn].hand[i_hand].hive_position == {-1, -1})
    assert(validate_hive())

    bug := players[player_with_turn].hand[i_hand].bug
    hive[hive_position.x][hive_position.y] = bug
    players[player_with_turn].hand[i_hand].hive_position = hive_position
    fmt.printfln("Player %d placed %s at %d %d", player_with_turn, bug, hive_position.x, hive_position.y)
    advance_turn()

    assert(validate_hive())
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

    // Update bounds for selecting pieces
    players[player_i].hand[hand_i].bounds.min = {offset.x-HEXAGON_WIDTH_FRACTION, offset.y-HEXAGON_HEIGHT_FRACTION}
    players[player_i].hand[hand_i].bounds.max = {offset.x+HEXAGON_WIDTH_FRACTION, offset.y+HEXAGON_HEIGHT_FRACTION}
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
    for j in 0..<HIVE_Y_LENGTH {
        offset.x = controller + (f32(j % 2) * HEXAGON_RADIUS * 1.5)
        // fmt.println(j, rotate, width, height)
        for i in 0..<HIVE_X_LENGTH {
            if hive[i][j] == .Empty {
                rl.DrawPolyLinesEx(offset, HEXAGON_SIDES, HEXAGON_RADIUS, 0, 1, rl.GRAY)
                rl.DrawTextEx(FONT, rl.TextFormat("%i %i", i, j), offset, FONT_SIZE, 2, rl.GRAY)
            }
            else {
                player_i, hand_i := lookup_hive_position({i, j})
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


