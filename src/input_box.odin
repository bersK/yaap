package game

import rl "vendor:raylib"

// Check if any key is pressed
// NOTE: We limit keys check to keys between 32 (KEY_SPACE) and 126
IsAnyKeyPressed :: proc() -> (keyPressed: bool) {
	key := rl.GetKeyPressed()

	if (i32(key) >= 32) && (i32(key) <= 126) {
		keyPressed = true
	}

	return
}
