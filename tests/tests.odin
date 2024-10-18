package tests

import m "../src/main"
import "core:testing"

@(test)
test_hive_whole :: proc(t: ^testing.T) {
    hive: [m.HIVE_X_LENGTH][m.HIVE_Y_LENGTH]m.Bug
    hive[0][0] = m.Bug.Queen
    hive[0][1] = m.Bug.Ant
    testing.expect(t, m.validate_hive(hive))
}

@(test)
test_hive_broken :: proc(t: ^testing.T) {
    hive: [m.HIVE_X_LENGTH][m.HIVE_Y_LENGTH]m.Bug
    hive[0][0] = m.Bug.Queen
    hive[0][9] = m.Bug.Ant
    testing.expect(t, !m.validate_hive(hive))
}
