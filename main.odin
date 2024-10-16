package main

import rl "vendor:raylib"
import "core:math"
import "core:fmt"
import "core:log"

HEXAGON_SIDES :: 6
HEXAGON_RADIUS: f32 = 40.0
HEXAGON_ANGLE: f32 = 2.0 * math.PI / HEXAGON_SIDES
HEXAGON_WIDTH: f32 = HEXAGON_RADIUS * 2
HEXAGON_HEIGHT: f32 = HEXAGON_RADIUS * math.SQRT_THREE

SCREEN_WIDTH  :: 900
SCREEN_HEIGHT :: 940
SCREEN_PADDING_X :: 50
SCREEN_PADDING_Y :: 50

SPACING_X :: 10
SPACING_Y :: 10

FONT_SIZE :: 12
FONT_SPACING :: 1
FONT: rl.Font

HIVE_HORIZONTAL_SIZE    :: 7
HIVE_VERTICAL_SIZE      :: 15
hive:           [HIVE_HORIZONTAL_SIZE][HIVE_VERTICAL_SIZE]Bug

PLAYERS :: 2
players: [PLAYERS]Player
player_with_turn: int // Index into the players array
HAND_SIZE :: 11

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

Piece :: struct {
    bug: Bug,
    bounds: Bounds,
    hive_position: [2]int,
}

Bug_Colors := [Bug]rl.Color {
	.Queen = rl.YELLOW,
	.Ant = rl.DARKBLUE,
	.Grasshopper = rl.LIME,
	.Spider = rl.RED,
	.Beetle = rl.BLUE,
	.Empty = rl.WHITE,
}

main :: proc() {
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Hive")
    defer rl.CloseWindow()   

    FONT = rl.GetFontDefault()

    init_game()

    rl.SetTargetFPS(60)      

    for !rl.WindowShouldClose() { // Detect window close button or ESC key
        update_game()
        draw_game()
    }
}


init_game :: proc() {

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
    assert(len(hive) == HIVE_HORIZONTAL_SIZE)
    hive = {}
    for i in 0..<HIVE_HORIZONTAL_SIZE {
        for j in 0..<HIVE_VERTICAL_SIZE {
            hive[i][j] = .Empty
        }
    }

    // Game sim
    place_piece({3, 8}, 4)
    advance_turn()
    place_piece({3, 7}, 4)
    advance_turn()
    place_piece({3, 10}, 0)

}

update_game :: proc() {

    if rl.IsMouseButtonPressed(rl.MouseButton.LEFT) {
        position := rl.GetMousePosition()
        for player, i in players {
            for piece, j in player.hand {
                if within_bounds(piece.bounds, position) && i == player_with_turn {
                    fmt.printf("Selected a %s from player_i %d at hand_i %d\n", piece.bug, i, j)
                }
            }
        }
    }

}

// get_distance :: proc(a: [2]i32, b: [2]i32) -> i32 {
//     return cast(i32) math.sqrt(math.pow(f64(a.y-b.y), 2) + math.pow(f64(a.x-b.x), 2))
// }

within_bounds :: proc(bounds: Bounds, position: rl.Vector2) -> (within: bool) {
    return bounds.min.x <= position.x && position.x <= bounds.max.x && 
           bounds.min.y <= position.y && position.y <= bounds.max.y

}

advance_turn :: proc() {
    player_with_turn += 1
    player_with_turn %= PLAYERS // Wrap around
    assert(player_with_turn < PLAYERS)
    assert(player_with_turn >= 0)
}

place_piece :: proc(hive_position: [2]int, i_hand: int) {
    assert(i_hand >= 0)
    assert(i_hand < len(players[player_with_turn].hand))
    assert(hive_position.x >= 0)
    assert(hive_position.y >= 0)
    assert(players[player_with_turn].hand[i_hand].hive_position == {-1, -1})

    hive[hive_position.x][hive_position.y] = players[player_with_turn].hand[i_hand].bug
    players[player_with_turn].hand[i_hand].hive_position = hive_position

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
    players[player_i].hand[hand_i].bounds.min = {offset.x-(HEXAGON_WIDTH/2), offset.y-(HEXAGON_HEIGHT/2)}
    players[player_i].hand[hand_i].bounds.max = {offset.x+(HEXAGON_WIDTH/2), offset.y+(HEXAGON_HEIGHT/2)}
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
    for j in 0..<HIVE_VERTICAL_SIZE {
        offset.x = controller + (f32(j % 2) * HEXAGON_RADIUS * 1.5)
        // fmt.println(j, rotate, width, height)
        for i in 0..<HIVE_HORIZONTAL_SIZE {
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
    offset.y += HEXAGON_HEIGHT

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


