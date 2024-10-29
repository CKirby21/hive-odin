package hive

import "core:log"

PLAYERS       :: 2
HAND_SIZE     :: 11
HIVE_X_LENGTH :: 15
HIVE_Y_LENGTH :: 40 

Hand_Bugs := [HAND_SIZE]Bug {
    .Queen,
    .Ant, .Ant, .Ant,
    .Grasshopper, .Grasshopper, .Grasshopper,
    .Spider, .Spider,
    .Beetle, .Beetle,
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
    .North     = {  0, -2 },
    .Northeast = {  1, -1 },
    .Southeast = {  1,  1 },
    .South     = {  0,  2 },
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

Logger_Opts :: log.Options{
	.Level,
	.Terminal_Color,
	.Short_File_Path,
	.Line,
}

