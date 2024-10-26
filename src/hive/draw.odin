package hive

import rl "vendor:raylib"
import "core:fmt"
import "core:log"
import "core:math"

HEXAGON_SIDES :: 6
HEXAGON_GAP :: 2
g_zoom: f32 = 1.0

SCREEN_WIDTH  :: 1000
SCREEN_HEIGHT :: 1000
SCREEN_PADDING_X :: 10
SCREEN_PADDING_Y :: 10

HIVE_WIDTH :: SCREEN_HEIGHT - (SCREEN_PADDING_X*2)
HIVE_HEIGHT :: 700

FONT_SIZE :: 12
HEADER_FONT_SIZE :: 24
FONT_SPACING :: 1
FONT: rl.Font

SPACING_X :: 0
SPACING_Y :: 5 

Hexagon :: struct {
    radius: f32,
    angle: f32,
    width: f32,
    height: f32,
    width_fraction: f32,
    height_fraction: f32,
}

Bug_Colors := [Bug]rl.Color {
    .Empty       = rl.WHITE,
    .Queen       = rl.YELLOW,
    .Ant         = rl.DARKBLUE,
    .Grasshopper = rl.LIME,
    .Spider      = rl.RED,
    .Beetle      = rl.BLUE,
}

// :TODO: Draw piece given the offset is the top left and not the center?
draw_piece :: proc(offset: rl.Vector2, player_i: int, hand_i: int, hexagon: Hexagon) {
    bug := g_players[player_i].hand[hand_i].bug
    log.assert(bug != .Empty, "Shouldn't be drawing an empty bug")

    rl.DrawPoly(offset, HEXAGON_SIDES, hexagon.radius, 0, g_players[player_i].color)
    // rl.DrawPolyLinesEx(offset, HEXAGON_SIDES, hexagon.radius, 0, 1, rl.BLACK)

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

    hexagon := get_hexagon(g_zoom)

    // Because offset is the center point of the next hexagon
    offset = { offset.x + (hexagon.width/2), offset.y + (hexagon.height/2) }
    controller := offset.x

    hive_length := [2]int{HIVE_X_LENGTH, HIVE_Y_LENGTH}
    measurer: rl.Vector2
    for i in 0..<HIVE_X_LENGTH {
        measurer.x += hexagon.radius * 3 + (2*HEXAGON_GAP)
        if measurer.x > HIVE_WIDTH {
            hive_length.x = i
            break
        }
    }
    for i in 0..<HIVE_Y_LENGTH {
        measurer.y += hexagon.height / 2
        if !is_even(i) {
            measurer.y += HEXAGON_GAP
        }
        if measurer.y > HIVE_HEIGHT {
            hive_length.y = i
            break
        }
    }
    assert(hive_length.x != 0)
    assert(hive_length.y != 0)
    center := get_start()
    hive_bounds: PositionBounds = {
        {center.x - (hive_length.x/2), center.y - (hive_length.y/2)},
        {center.x + (hive_length.x/2), center.y + (hive_length.y/2)}
    }

    // Draw da hive
    for y in hive_bounds.min.y..<hive_bounds.max.y {
        offset.x = controller + (f32(y % 2) * hexagon.radius * 1.5)
        if !is_even(y) {
            offset.x += HEXAGON_GAP
        }
        // fmt.println(j, rotate, width, height)
        for x in hive_bounds.min.x..<hive_bounds.max.x {
            if is_empty({x, y}) {
                if g_args.draw_grid {
                    rl.DrawPolyLinesEx(offset, HEXAGON_SIDES, hexagon.radius, 0, 1, rl.GRAY)
                    rl.DrawTextEx(FONT, rl.TextFormat("%i %i", x, y), offset, FONT_SIZE, 2, rl.GRAY)
                }
            }
            else {
                piece, empty := get_top_piece({x, y})
                assert(!empty)
                draw_piece(offset, piece.player_i, piece.hand_i, hexagon)
            }
            if should_highlight({x, y}, offset) {
                rl.DrawPolyLinesEx(offset, HEXAGON_SIDES, hexagon.radius, 0, 3, rl.BLUE)
            }
            offset.x += 3 * hexagon.radius + (2*HEXAGON_GAP)
        }

        offset.y += hexagon.height / 2
        if !is_even(y) {
            offset.y += HEXAGON_GAP
        }
    }

    // Draw bugs in each player's hand
    hexagon = get_hexagon(1.0)
    offset = { 
        (SCREEN_WIDTH/2) - (hexagon.width*HAND_SIZE/2) + (hexagon.width/2), 
        offset.y + SPACING_Y + (hexagon.height/2) 
    }
    controller = offset.x
    for player, i in g_players {
        offset.x = controller
        for piece, j in player.hand {

            // Go to next line if bugs don't fit
            if offset.x > SCREEN_WIDTH - SCREEN_PADDING_X {
                offset.x = controller
                offset.y += hexagon.height + SPACING_Y
            }

            if piece.hive_position == {-1, -1} {
                draw_piece(offset, i, j, hexagon)
            }
            else {
                // Don't draw bugs that are no longer in the player's hand
            }
            offset.x += hexagon.width + SPACING_X

        }
        offset.y += hexagon.height + SPACING_Y
    }

}

get_hexagon :: proc(zoom: f32) -> Hexagon {
    radius: f32 = 40.0 * zoom
    angle: f32 = 2.0 * math.PI / HEXAGON_SIDES
    width: f32 = radius * 2
    height: f32 = radius * math.SQRT_THREE
    width_fraction: f32 = width / 2.7
    height_fraction: f32 = height / 2
    return Hexagon {
        radius,
        angle,
        width,
        height,
        width_fraction,
        height_fraction,
    }
}

