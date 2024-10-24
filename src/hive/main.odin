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
QUEENS       :: 1
ANTS         :: 3
GRASSHOPPERS :: 3
SPIDERS      :: 2
BEETLES      :: 2
HAND_SIZE :: QUEENS+ANTS+GRASSHOPPERS+SPIDERS+BEETLES

HIVE_X_LENGTH    :: 15
HIVE_Y_LENGTH      :: 40 
g_hive: [HIVE_X_LENGTH][HIVE_Y_LENGTH]Stack
g_placeables: sa.Small_Array(HAND_SIZE * PLAYERS * 6, Piece)

g_playback_file: os.Handle

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
// Hive :: [HIVE_X_LENGTH][HIVE_Y_LENGTH]Stack
Stack :: sa.Small_Array(1+BEETLES*PLAYERS, Bug)

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

    g_playback_file = create_playback_file()

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
    os.close(g_playback_file)
}

init_game :: proc() {

    log.debug("Initializing state...")

    // Init Players
    assert(len(g_players) == PLAYERS)
    g_players = {}
    for i in 0..<PLAYERS {
        bounds := Bounds{ rl.Vector2{-1,-1}, rl.Vector2{-1,-1} }
        hive_position := [2]int{-1,-1}
        piece := Piece{ .Empty, bounds, hive_position }
        for j in 0..<HAND_SIZE {
            g_players[i].hand[j] = piece
        }
        set_hand_bugs(&g_players[i].hand, .Queen, QUEENS)
        set_hand_bugs(&g_players[i].hand, .Ant, ANTS)
        set_hand_bugs(&g_players[i].hand, .Grasshopper, GRASSHOPPERS)
        set_hand_bugs(&g_players[i].hand, .Spider, SPIDERS)
        set_hand_bugs(&g_players[i].hand, .Beetle, BEETLES)
    }
    g_player_with_turn = 0

    // Assign player colors
    assert(len(g_players) == 2)
    g_players[0].color = rl.BEIGE
    g_players[1].color = rl.BLACK

    // Init Hive
    assert(len(g_hive) == HIVE_X_LENGTH)
    g_hive = {}
    // for i in 0..<HIVE_X_LENGTH {
    //     for j in 0..<HIVE_Y_LENGTH {
    //         // :FIXME:
    //         stack: Stack
    //         sa.append(&stack, Bug.Empty)
    //         g_hive[i][j] = stack
    //     }
    // }

    sa.clear(&g_placeables)
    g_source = -1

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
                if within_bounds(piece.bounds, mouse) && i == g_player_with_turn {
                    log.debugf("Selected a <%s> from Player <%d> at hand_i <%d>\n", piece.bug, i, j)
                    
                    err: bool 
                    if is_in_hand(j) {
                        err = populate_places()
                    } else {
                        err = populate_moves(j)
                    }
                    if !err {
                        g_source = j
                    }
                }
            }
        }
        for i in 0..<sa.len(g_placeables) {
            piece := sa.get(g_placeables, i)
            if within_bounds(piece.bounds, mouse) {
                log.assertf(0 <= g_source && g_source < HAND_SIZE, "%d", g_source)
                place_piece(piece.hive_position)
            }
        }
    }
}

// Validates that the hive is not broken, meaning that every bug 
// is attached to at least one other bug
//
// Caller is responsible for asserting that the return value is true
validate_hive :: proc(hive: [HIVE_X_LENGTH][HIVE_Y_LENGTH]Stack) -> (valid_hive: bool) {

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
    log.assertf(0 <= slide_count && slide_count < sa.len(slides) - 1, "%d", slide_count)
    left := Piece{.Empty, Bounds{}, sa.get(slides, slide_count-1).position }
    sa.append(&g_placeables, left)
    right := Piece{.Empty, Bounds{}, sa.get(slides, sa.len(slides)-slide_count).position }
    sa.append(&g_placeables, right)
}


populate_moves :: proc(i_hand: int) -> (err: bool) {

    log.assert(!is_in_hand(i_hand),
        "Function should only be called if piece is already placed in the hive")

    sa.clear(&g_placeables)

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
            placeable_piece := Piece{.Empty, Bounds{}, sa.get(slides, i).position}
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
            placeable_piece := Piece{.Empty, Bounds{}, curr}
            sa.append(&g_placeables, placeable_piece)
        }
    case .Spider:
        populate_distinct_slides(piece.hive_position, hive, 3)
    case .Beetle:
        populate_distinct_slides(piece.hive_position, hive, 1)
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
            log.assertf(!err, "%d %d", neighbor.x, neighbor.y)
            placeable_piece.hive_position = neighbor
            sa.append(&g_placeables, placeable_piece)
        }
        return false
    }

    // The bounds are smaller to avoid going outside the hive
    for x in 1..<HIVE_X_LENGTH-1 {
        for y in 1..<HIVE_Y_LENGTH-1 {

            friendlies := 0
            enemies := 0
            position := [2]int{x, y}
            for direction in Direction {
                neighbor, err := get_neighbor(position, direction)
                if err {
                    continue
                }
                if is_empty(neighbor) {
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

advance_turn :: proc() {
    log.assertf(0 <= g_player_with_turn && g_player_with_turn < PLAYERS, "%d", g_player_with_turn)

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

place_piece :: proc(target: [2]int) {
    log.assertf(0 <= g_source && g_source < HAND_SIZE, "%d", g_source)
    log.assertf(0 <= target.x && target.x < HIVE_X_LENGTH, "%d", target.x)
    log.assertf(0 <= target.y && target.y < HIVE_Y_LENGTH, "%d", target.y)
    assert(is_empty(target, g_hive))
    assert(validate_hive(g_hive))

    if !is_in_hand(g_source) {
        source := g_players[g_player_with_turn].hand[g_source].hive_position
        sa.pop_back(&g_hive[source.x][source.y])
    }

    os.write_string(g_playback_file, fmt.aprintln(g_source, target.x, target.y))

    bug := g_players[g_player_with_turn].hand[g_source].bug
    sa.append(&g_hive[target.x][target.y], bug)
    g_players[g_player_with_turn].hand[g_source].hive_position = target
    log.debugf("Player <%d> placed <%s> at <%d %d>", g_player_with_turn, bug, target.x, target.y)
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

