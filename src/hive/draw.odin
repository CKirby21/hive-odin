package hive

import rl "vendor:raylib"
import "core:fmt"
import "core:log"
import "core:math"

HEXAGON_SIDES :: 6
HEXAGON_RADIUS: f32 = 40.0
HEXAGON_ANGLE: f32 = 2.0 * math.PI / HEXAGON_SIDES
HEXAGON_WIDTH: f32 = HEXAGON_RADIUS * 2
HEXAGON_HEIGHT: f32 = HEXAGON_RADIUS * math.SQRT_THREE
HEXAGON_WIDTH_FRACTION: f32 = HEXAGON_WIDTH / 2.7
HEXAGON_HEIGHT_FRACTION: f32 = HEXAGON_HEIGHT / 2

SCREEN_WIDTH  :: 1000
SCREEN_HEIGHT :: 1000
SCREEN_PADDING_X :: 10
SCREEN_PADDING_Y :: 10

FONT_SIZE :: 12
HEADER_FONT_SIZE :: 24
FONT_SPACING :: 1
FONT: rl.Font

SPACING_X :: 0
SPACING_Y :: 5 

DRAW_GRID :: true

Bug_Colors := [Bug]rl.Color {
    .Empty       = rl.WHITE,
    .Queen       = rl.YELLOW,
    .Ant         = rl.DARKBLUE,
    .Grasshopper = rl.LIME,
    .Spider      = rl.RED,
    .Beetle      = rl.BLUE,
}

draw_piece :: proc(offset: rl.Vector2, player_i: int, hand_i: int) {
    bug := g_players[player_i].hand[hand_i].bug
    log.assert(bug != .Empty, "Shouldn't be drawing an empty bug")

    rl.DrawPoly(offset, HEXAGON_SIDES, HEXAGON_RADIUS, 0, g_players[player_i].color)
    rl.DrawPolyLinesEx(offset, HEXAGON_SIDES, HEXAGON_RADIUS, 0, 1, rl.BLACK)

    // Draw text inside piece
    text := rl.TextFormat("%s", bug)
    text_size := rl.MeasureTextEx(FONT, text, FONT_SIZE, FONT_SPACING)
    text_offset: rl.Vector2 = {offset.x-(text_size.x/2), offset.y-(text_size.y/2)}
    rl.DrawTextEx(FONT, text, text_offset, FONT_SIZE, FONT_SPACING, Bug_Colors[bug])

    update_bounds(&g_players[player_i].hand[hand_i].bounds, offset)
}

draw_game :: proc() {
    rl.BeginDrawing()
    defer rl.EndDrawing()

    rl.ClearBackground(rl.RAYWHITE)


    offset := rl.Vector2 {
        SCREEN_PADDING_X,
        SCREEN_PADDING_Y,
    }

    text := rl.TextFormat("Player %i's turn.", g_player_with_turn)
    #partial switch get_game_outcome(g_hive) {
    case .Tie:
        text = rl.TextFormat("There be a tie.")
    case .Win:
        for winner, i in get_winners(g_hive) {
            if winner {
                text = rl.TextFormat("Player %i has won!", i)
                break
            }
        }
    }
    text_size := rl.MeasureTextEx(FONT, text, HEADER_FONT_SIZE, FONT_SPACING)
    text_offset: rl.Vector2 = { (SCREEN_WIDTH/2)-(text_size.x/2), offset.y }
    rl.DrawTextEx(FONT, text, text_offset, HEADER_FONT_SIZE, FONT_SPACING, rl.BLACK)
    offset.y += text_size.y + SPACING_Y

    // Because offset is the center point of the next hexagon
    offset = { offset.x + (HEXAGON_WIDTH/2), offset.y + (HEXAGON_HEIGHT/2) }
    controller := offset.x

    // Draw da hive
    for y in 0..<HIVE_Y_LENGTH {
        offset.x = controller + (f32(y % 2) * HEXAGON_RADIUS * 1.5)
        // fmt.println(j, rotate, width, height)
        for x in 0..<HIVE_X_LENGTH {
            if g_hive[x][y] == .Empty {
                if DRAW_GRID {
                    rl.DrawPolyLinesEx(offset, HEXAGON_SIDES, HEXAGON_RADIUS, 0, 1, rl.GRAY)
                    rl.DrawTextEx(FONT, rl.TextFormat("%i %i", x, y), offset, FONT_SIZE, 2, rl.GRAY)
                }
                if should_highlight({x, y}, offset) {
                    rl.DrawPolyLinesEx(offset, HEXAGON_SIDES, HEXAGON_RADIUS, 0, 3, rl.BLUE)
                }
            }
            else {
                player_i, hand_i := lookup_hive_position({x, y})
                draw_piece(offset, player_i, hand_i)
            }
            offset.x += 3 * HEXAGON_RADIUS
        }

        offset.y += HEXAGON_HEIGHT / 2
    }
    offset.y += (HEXAGON_HEIGHT/2) +SPACING_Y

    // Draw bugs in each player's hand
    offset = { (SCREEN_WIDTH/2)-(HEXAGON_WIDTH*HAND_SIZE/2)+(HEXAGON_WIDTH/2), offset.y }
    controller = offset.x
    for player, i in g_players {
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
