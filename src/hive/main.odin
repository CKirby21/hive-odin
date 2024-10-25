package hive

import rl "vendor:raylib"
import "core:math"
import "core:fmt"
import "core:log"
import "core:time"
import "core:os"
import "core:slice"
import sa "core:container/small_array"

PLAYERS :: 2
g_players: [PLAYERS]Player
g_eliminations: [PLAYERS]bool
g_player_with_turn: int // Index into the g_players array
g_source: int // Index into the player with turn's hand
g_destination: int // Index into the placeables array
HAND_SIZE    :: 11

HIVE_X_LENGTH    :: 15
HIVE_Y_LENGTH      :: 40 
g_hive: Hive
g_placeables: sa.Small_Array(HAND_SIZE * PLAYERS * 6, Piece)

g_sim := false
g_playback_output_file: os.Handle

Hand_Bugs := [HAND_SIZE]Bug {
    .Queen,
    .Ant, .Ant, .Ant,
    .Grasshopper, .Grasshopper, .Grasshopper,
    .Spider, .Spider,
    .Beetle, .Beetle,
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

Adjacent_Directions := [Direction][2]Direction {
    .North     = { .Northwest, .Northeast },
    .Northeast = { .North,     .Southeast },
    .Southeast = { .Northeast, .South },
    .South     = { .Southeast, .Southwest },
    .Southwest = { .South,     .Northwest },
    .Northwest = { .Southwest, .North },
}

Opposite_Directions := [Direction]Direction {
    .North     = .South,
    .Northeast = .Southwest,
    .Southeast = .Northwest,
    .South     = .North,
    .Southwest = .Northeast,
    .Northwest = .Southeast,
}

// :TODO: Update size for mosquitoes once they are added
Hive :: [HIVE_X_LENGTH][HIVE_Y_LENGTH]Stack
Stack :: sa.Small_Array(HAND_SIZE/2, Piece)

Slide :: struct {
    position: [2]int,
    direction: Direction
}

Bounds :: struct {
    min: rl.Vector2,
    max: rl.Vector2,
}

PositionBounds :: struct {
    min: [2]int,
    max: [2]int,
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
    player_i: int,
    hand_i: int,
}

Logger_Opts :: log.Options{
	.Level,
	.Terminal_Color,
	.Short_File_Path,
	.Line,
}

main :: proc() {
    context.assertion_failure_proc = report_assertion_failure

    logger := log.create_console_logger(log.Level.Debug, Logger_Opts)
    context.logger = logger
    defer log.destroy_console_logger(logger)

    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "")
    defer rl.CloseWindow()   
    
    FONT = rl.GetFontDefault()
    rl.SetTargetFPS(60)

    playback_input_filepath := ""
    if len(os.args) == 2 {
        g_sim = true
        playback_input_filepath = os.args[1]
    }

    if g_sim {
        setup_playback(playback_input_filepath)
    } else {
        // Only create the playback file for real games
        g_playback_output_file = create_playback_output_file()
        defer os.close(g_playback_output_file)
    }

    init_game()
    for !rl.WindowShouldClose() { // Detect window close button or ESC key
        if g_sim {
            finished := playback_line()
            if finished {
                log.debug("Playback finished")
                break
            }
        }
        update_game()
        draw_game()
    }
}

init_game :: proc() {

    log.debug("Initializing state...")

    // Init Players
    assert(len(g_players) == PLAYERS)
    g_players = {}
    for i in 0..<PLAYERS {
        for j in 0..<HAND_SIZE {
            g_players[i].hand[j] = new_piece(bug=Hand_Bugs[j], player_i=i, hand_i=j)
        }
    }
    g_player_with_turn = 0

    // Assign player colors
    assert(len(g_players) == 2)
    g_players[0].color = rl.BEIGE
    g_players[1].color = rl.BLACK

    // Init Hive
    assert(len(g_hive) == HIVE_X_LENGTH)
    g_hive = {}

    init_turn_variables()

    log.debug("Finished initializing state.")
}

update_game :: proc() {

    step: f32 = .1
    g_zoom += rl.GetMouseWheelMove() * step 
    if g_zoom < 0.5 { g_zoom = 0.5 }
    if g_zoom > 2 { g_zoom = 2 }

    switch get_game_outcome(g_hive) {
    case .Undecided:
        // Do nothing
    case .Elimination:
        g_eliminations = get_losers(g_hive)
    case .Tie, .Win:
        return
    }

    if rl.IsMouseButtonPressed(rl.MouseButton.LEFT) {
        mouse := rl.GetMousePosition()
        for player, i in g_players {
            for piece, j in player.hand {
                if within_bounds(piece.bounds, mouse) && i == g_player_with_turn && g_source == -1 {
                    g_source = j
                    write_playback_source(g_source)
                }
            }
        }
        for destination in 0..<sa.len(g_placeables) {
            piece := sa.get(g_placeables, destination)
            if within_bounds(piece.bounds, mouse) && g_destination == -1 {
                g_destination = destination
                write_playback_destination(g_destination)
            }
        }
    }

    // Force the player to place their queen
    if get_friendlies() == 3 && !is_friendly_queen_played(g_player_with_turn) {
        g_source = get_hand_i(.Queen)
    }

    // Decide if the g_source is legit. If it isn't, then clear it
    if g_source != -1 && sa.len(g_placeables) == 0 {
        err: bool = true
        piece := g_players[g_player_with_turn].hand[g_source]
        if is_in_hand(piece.hand_i) {
            err = populate_places()
        } else if is_move_allowed(piece) {
            err = populate_moves(piece.hand_i)
        }

        if err {
            init_turn_variables()
            log.debugf("Tried to select a <%s> from Player <%d> at hand_i <%d>\n", piece.bug, g_player_with_turn, g_source)
        } else {
            log.debugf("Selected a <%s> from Player <%d> at hand_i <%d>\n", piece.bug, g_player_with_turn, g_source)
        }
    }
    else if g_destination != -1 {
        assert(sa.len(g_placeables) != 0)
        log.assertf(0 <= g_source && g_source < HAND_SIZE, "%d", g_source)
        log.debugf("Selected a destination <%d>\n", g_destination)
        place_piece()
        init_turn_variables()
    }
}

// Validates that the hive is not broken, meaning that every bug 
// is attached to at least one other bug
//
// Caller is responsible for asserting that the return value is true
validate_hive :: proc(hive: Hive) -> (valid_hive: bool) {

    valid_hive = true

    occupied := get_occupied_positions(hive)
    if occupied <= 1 {
        return true
    }
    neighbors: sa.Small_Array(HAND_SIZE * PLAYERS, [2]int)

    out:
    for x in 0..<HIVE_X_LENGTH {
        for y in 0..<HIVE_Y_LENGTH {
            if !is_empty({x, y}, hive) {
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
            log.assertf(!err, "%d %d", neighbor.x, neighbor.y)
            if is_empty(neighbor, hive) {
                continue
            }
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

slide :: proc(curr: ^Slide, hive := g_hive, curr_start := false) {

    for direction in Direction {
        // We want to skip this check if current is the start
        if !curr_start {
            explored_direction := Opposite_Directions[curr.direction]
            // We don't want to go back the way we came
            if direction == explored_direction {
                continue
            }
        }
        neighbor, err := get_neighbor(curr.position, direction)
        log.assertf(!err, "%d %d", neighbor.x, neighbor.y)
        if !is_empty(neighbor, hive) {
            continue
        }
        // Investigate neighbor's neighbors
        neighbor_count := 0
        empties: [Direction]bool
        for neighbor_direction in Direction {
            neighbor_neighbor, err := get_neighbor(neighbor, neighbor_direction)
            log.assertf(!err, "%d %d", neighbor_neighbor.x, neighbor_neighbor.y)
            if is_empty(neighbor_neighbor, hive) {
                empties[neighbor_direction] = true
            } else {
                neighbor_count += 1
            }
        }
        opposite := Opposite_Directions[direction]
        left := Adjacent_Directions[opposite][0] 
        right := Adjacent_Directions[opposite][1] 
        can_slide := empties[left] ~ empties[right]
        if neighbor_count > 0 && can_slide {
            curr^ = Slide{ neighbor, direction }
            return
        }
    }
}

get_slides :: proc(position: [2]int, hive := g_hive) -> 
    (slides: sa.Small_Array(HAND_SIZE*PLAYERS*6, Slide)) {

    curr := Slide{}
    curr.position = position
    slide(&curr, hive, true)

    for curr.position != position {
        ok := sa.append(&slides, curr)
        assert(ok)
        slide(&curr, hive)
    }
    return slides
}

populate_distinct_slides :: proc(position: [2]int, hive := g_hive, slide_count: int) {
    slides := get_slides(position, hive)
    if sa.len(slides) == 0 {
        return
    }
    log.assertf(0 <= slide_count && slide_count < sa.len(slides) - 1, "%d", slide_count)
    left := Piece{.Empty, Bounds{}, sa.get(slides, slide_count-1).position, -1, -1 }
    sa.append(&g_placeables, left)
    right := Piece{.Empty, Bounds{}, sa.get(slides, sa.len(slides)-slide_count).position, -1, -1 }
    sa.append(&g_placeables, right)
}


populate_moves :: proc(i_hand: int) -> (err: bool) {

    log.assert(!is_in_hand(i_hand),
        "Function should only be called if piece is already placed in the hive")

    // This is so that the current position does not contribute to the logic below
    piece := g_players[g_player_with_turn].hand[i_hand]
    hive := g_hive
    sa.pop_back(&hive[piece.hive_position.x][piece.hive_position.y])

    // Check if moving would break the hive
    if !validate_hive(hive) {
        err = true
        return err
    }


    switch piece.bug {
    case .Empty:
        panic("Should never be populating moves for an empty bug")
    case .Queen:
        populate_distinct_slides(piece.hive_position, hive, 1)
    case .Ant:
        slides := get_slides(piece.hive_position, hive)
        for i in 0..<sa.len(slides) {
            placeable_piece := Piece{.Empty, Bounds{}, sa.get(slides, i).position, -1, -1}
            sa.append(&g_placeables, placeable_piece)
        }
    case .Grasshopper:
        for direction in Direction {
            curr, err := get_neighbor(piece.hive_position, direction)
            if is_empty(curr, hive) {
                continue
            }
            for !is_empty(curr, hive) {
                curr, err = get_neighbor(curr, direction)
            }
            placeable_piece := Piece{.Empty, Bounds{}, curr, -1, -1}
            sa.append(&g_placeables, placeable_piece)
        }
    case .Spider:
        populate_distinct_slides(piece.hive_position, hive, 3)
    case .Beetle:
        stack := g_hive[piece.hive_position.x][piece.hive_position.y]
        if sa.len(stack) > 1 {
            // Assume beetle can be moved to any of its neighbor positions.
            // :FIXME: This is not true in rare circumstances
            for direction in Direction {
                neighbor, err := get_neighbor(piece.hive_position, direction)
                placeable_piece := Piece{.Empty, Bounds{}, neighbor, -1, -1}
                sa.append(&g_placeables, placeable_piece)
            }
        } else {
            populate_distinct_slides(piece.hive_position, hive, 1)
            // Beetle can hop on top
            for direction in Direction {
                neighbor, err := get_neighbor(piece.hive_position, direction)
                if !is_empty(neighbor, hive) {
                    placeable_piece := Piece{.Empty, Bounds{}, neighbor, -1, -1}
                    sa.append(&g_placeables, placeable_piece)
                }
            }
        }
    }

    if sa.len(g_placeables) == 0 {
        err = true
    }

    return err
}

populate_places :: proc() -> (err: bool) {

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
            log.assertf(!err, "%d %d", neighbor.x, neighbor.y)
            placeable_piece.hive_position = neighbor
            sa.append(&g_placeables, placeable_piece)
        }
        return false
    }

    // The bounds are smaller to avoid going outside the hive
    for x in 1..<HIVE_X_LENGTH-1 {
        for y in 1..<HIVE_Y_LENGTH-1 {

            position := [2]int{x, y}
            if !is_empty(position) {
                continue
            }
            friendlies := 0
            enemies := 0
            for direction in Direction {
                neighbor, err := get_neighbor(position, direction)
                if err {
                    continue
                }
                if is_empty(neighbor) {
                    continue
                }
                piece, _ := get_top_piece(neighbor)
                if piece.player_i == g_player_with_turn {
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

advance_turn :: proc() {
    log.assertf(0 <= g_player_with_turn && g_player_with_turn < PLAYERS, "%d", g_player_with_turn)
    init_turn_variables()

    for _ in 0..<PLAYERS {
        g_player_with_turn += 1
        g_player_with_turn %= PLAYERS // Wrap around
        if g_eliminations[g_player_with_turn] == false {
            break
        }
    }
    log.assert(g_eliminations[g_player_with_turn] == false, "At least one player should not eliminated")
    // fmt.printfln("Player <%d>'s turn", g_player_with_turn)
    log.assertf(0 <= g_player_with_turn && g_player_with_turn < PLAYERS, "%d", g_player_with_turn)
}

// g_source is index into the player's hand
// g_destination is index into the placeables array
place_piece :: proc() {
    log.assertf(0 <= g_source && g_source < HAND_SIZE, "%d", g_source)
    log.assertf(0 <= g_destination && g_destination < sa.len(g_placeables), "%d", g_destination)
    position := sa.get(g_placeables, g_destination).hive_position
    log.assertf(0 <= position.x && position.x < HIVE_X_LENGTH, "%d", position.x)
    log.assertf(0 <= position.y && position.y < HIVE_Y_LENGTH, "%d", position.y)
    assert(validate_hive(g_hive))

    if !is_in_hand(g_source) {
        g_source := g_players[g_player_with_turn].hand[g_source].hive_position
        sa.pop_back(&g_hive[g_source.x][g_source.y])
    }

    piece := g_players[g_player_with_turn].hand[g_source]
    sa.append(&g_hive[position.x][position.y], piece)
    g_players[g_player_with_turn].hand[g_source].hive_position = position
    log.debugf("Player <%d> placed <%s> at <%d %d>", g_player_with_turn, piece.bug, position.x, position.y)

    advance_turn()

    assert(validate_hive(g_hive))
}

init_turn_variables :: proc() {
    g_source = -1
    g_destination = -1
    sa.clear(&g_placeables)
}

should_highlight :: proc(hive_position: [2]int, offset: rl.Vector2) -> (highlight: bool) {
    for i in 0..<sa.len(g_placeables) {
        piece: ^Piece = sa.get_ptr(&g_placeables, i)
        if piece.hive_position == hive_position {
            update_bounds(&piece.bounds, offset) // :FIX: Not sure if i like this here
            highlight = true
        }
    }
    return highlight
}

