package main

import rl "vendor:raylib"
import "core:math"
import "core:fmt"

HEXAGON_RADIUS: f64 = 40.0
HEXAGON_ANGLE: f64 = 2.0 * math.PI / 6
HEXAGON_WIDTH: f64 = HEXAGON_RADIUS * 2
HEXAGON_HEIGHT: f64 = HEXAGON_RADIUS * math.SQRT_THREE

GRID_HORIZONTAL_SIZE    :: 5
GRID_VERTICAL_SIZE      :: 5

SCREEN_WIDTH  :: 800
SCREEN_HEIGHT :: 450

grid:           [GRID_HORIZONTAL_SIZE][GRID_VERTICAL_SIZE]rune

main :: proc() {
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Hive")
    defer rl.CloseWindow()   

    init_game()

    rl.SetTargetFPS(60)      

    for !rl.WindowShouldClose() { // Detect window close button or ESC key
        update_game()
        draw_game()
    }
}


init_game :: proc() {
    grid = {}

    // Initialize grid matrices
    for i in 0..<GRID_HORIZONTAL_SIZE {
        for j in 0..<GRID_VERTICAL_SIZE {
            grid[i][j] = 'A'
        }
    }
}

update_game :: proc() {


}

get_distance :: proc(a: [2]i32, b: [2]i32) -> i32 {
    return cast(i32) math.sqrt(math.pow(f64(a.y-b.y), 2) + math.pow(f64(a.x-b.x), 2))
}

draw_hexagon :: proc(center: [2]i32) {

    vertices: [6][2]i32

    for i in 0..<len(vertices) {
        theta := HEXAGON_ANGLE * f64(i)
        x_translation := i32(HEXAGON_RADIUS * math.cos(theta))
        y_translation := i32(HEXAGON_RADIUS * math.sin(theta))
        x := center.x + x_translation
        y := center.y + y_translation
        vertices[i] = [2]i32{x, y}
    }

    for i in 0..<len(vertices) {
        i_next := (i+1) % len(vertices)
        rl.DrawLine(vertices[i].x, vertices[i].y, vertices[i_next].x, vertices[i_next].y, rl.LIGHTGRAY)
        // rl.DrawText(rl.TextFormat("%i", i), vertices[i].x, vertices[i].y, 10, rl.GRAY)
    }
}

draw_game :: proc() {
    rl.BeginDrawing()
    defer rl.EndDrawing()

    rl.ClearBackground(rl.RAYWHITE)

    offset := [2]i32{
        100,
        100
        // SCREEN_WIDTH/2 - (GRID_HORIZONTAL_SIZE*HEXAGON_WIDTH/2) - 50,
        // SCREEN_HEIGHT/2 - ((GRID_VERTICAL_SIZE-1)*HEXAGON_HEIGHT/2) + HEXAGON_HEIGHT*2,
    }

    controller := offset.x

    for j in 0..<GRID_VERTICAL_SIZE {
        offset.x = controller + (i32(j % 2) * i32(HEXAGON_RADIUS + (HEXAGON_RADIUS/2)))
        // fmt.println(j, rotate, width, height)
        for i in 0..<GRID_HORIZONTAL_SIZE {
            draw_hexagon(offset)
            rl.DrawText(rl.TextFormat("%i %i", j, i), offset.x, offset.y, 10, rl.GRAY)
            offset.x += i32(3 * HEXAGON_RADIUS)
        }

        offset.y += i32(HEXAGON_HEIGHT / 2)
    }

}

