package tests

import h "../src/hive"
import "core:testing"

@(test)
test_hive_whole :: proc(t: ^testing.T) {
    hive: [h.HIVE_X_LENGTH][h.HIVE_Y_LENGTH]h.Bug
    hive[0][0] = h.Bug.Queen
    hive[0][1] = h.Bug.Ant
    testing.expect(t, h.validate_hive(hive))
}

@(test)
test_hive_broken :: proc(t: ^testing.T) {
    hive: [h.HIVE_X_LENGTH][h.HIVE_Y_LENGTH]h.Bug
    hive[0][0] = h.Bug.Queen
    hive[0][9] = h.Bug.Ant
    testing.expect(t, !h.validate_hive(hive))
}
