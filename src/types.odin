package hive

import rl "vendor:raylib"
import sa "core:container/small_array"

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

Args :: struct {
    playback_input_filepath: string,
    draw_grid: bool
}

