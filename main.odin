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

Player :: struct {
    id: int,
    hand: [11]Bug,
    hive_positions: [11][2]int,
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
    for i in 0..<PLAYERS {
        players[i] = Player{ }
        players[i].id = i+1
        players[i].hand[0] = .Queen
        players[i].hand[1] = .Ant
        players[i].hand[2] = .Ant
        players[i].hand[3] = .Ant
        players[i].hand[4] = .Grasshopper
        players[i].hand[5] = .Grasshopper
        players[i].hand[6] = .Grasshopper
        players[i].hand[7] = .Spider
        players[i].hand[8] = .Spider
        players[i].hand[9] = .Beetle
        players[i].hand[10] = .Beetle
        for j in 0..<len(players[i].hive_positions) {
            players[i].hive_positions[j] = {-1, -1}
        }
    }

    // Assign player colors
    assert(len(players) == 2)
    players[0].color = rl.BEIGE
    players[1].color = rl.BLACK

    // Init Hive
    hive = {}
    for i in 0..<HIVE_HORIZONTAL_SIZE {
        for j in 0..<HIVE_VERTICAL_SIZE {
            hive[i][j] = .Empty
        }
    }

    // place_bug(&players[0], {2, 5}, 0)

}

update_game :: proc() {


}

// get_distance :: proc(a: [2]i32, b: [2]i32) -> i32 {
//     return cast(i32) math.sqrt(math.pow(f64(a.y-b.y), 2) + math.pow(f64(a.x-b.x), 2))
// }

place_bug :: proc(player: ^Player, hive_position: [2]int, i_hand: int) {
    log.assert(i_hand >= 0)
    log.assert(i_hand < len(player.hand))
    log.assert(hive_position.x >= 0)
    log.assert(hive_position.y >= 0)
    log.assert(player.hive_positions[i_hand] == {-1, -1})

    hive[hive_position.x][hive_position.y] = player.hand[i_hand]
    player.hive_positions[i_hand] = hive_position
    player.hand[i_hand] = .Empty

}

lookup_color :: proc(hive_position: [2]int) -> rl.Color {
    log.assert(hive_position.x >= 0)
    log.assert(hive_position.y >= 0)

    color := rl.RAYWHITE
    for player in players {
        for i in 0..<len(player.hive_positions) {
            if player.hive_positions[i] == hive_position {
                color = player.color
            }
        }
    }

    log.assert(color != rl.RAYWHITE, "Color should have been found. Was the lookup array not populated?")
    return color
}

draw_bug :: proc(offset: rl.Vector2, bug: Bug, color: rl.Color) {
    log.assert(bug != .Empty, "Shouldn't be drawing an empty bug")
    rl.DrawPoly(offset, HEXAGON_SIDES, HEXAGON_RADIUS, 0, color)
    text := rl.TextFormat("%s", bug)
    text_size := rl.MeasureTextEx(FONT, text, FONT_SIZE, FONT_SPACING)
    text_offset: rl.Vector2 = {offset.x-(text_size.x/2), offset.y-(text_size.y/2)}
    rl.DrawTextEx(FONT, text, text_offset, FONT_SIZE, FONT_SPACING, Bug_Colors[bug])
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

    for j in 0..<HIVE_VERTICAL_SIZE {
        offset.x = controller + (f32(j % 2) * HEXAGON_RADIUS * 1.5)
        // fmt.println(j, rotate, width, height)
        for i in 0..<HIVE_HORIZONTAL_SIZE {
            bug := hive[i][j]
            if bug == .Empty {
                rl.DrawPolyLinesEx(offset, HEXAGON_SIDES, HEXAGON_RADIUS, 0, 1, rl.GRAY)
                rl.DrawTextEx(FONT, rl.TextFormat("%i %i", j, i), offset, FONT_SIZE, 2, rl.GRAY)
            }
            else {
                draw_bug(offset, bug, lookup_color({i, j}))
            }
            offset.x += 3 * HEXAGON_RADIUS
        }

        offset.y += HEXAGON_HEIGHT / 2
    }

    // Add some spacing between the hive and the player hands
    offset.y += HEXAGON_HEIGHT

    for player, j in players {
        offset.x = controller
        for bug in player.hand {
            if bug != .Empty {
                draw_bug(offset, bug, player.color)
                offset.x += HEXAGON_WIDTH + SPACING_X
            }
            if offset.x > SCREEN_WIDTH - SCREEN_PADDING_X {
                offset.x = controller
                offset.y += HEXAGON_HEIGHT + SPACING_Y
            }
        }
        offset.y += HEXAGON_HEIGHT + SPACING_Y
    }

}


