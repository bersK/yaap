// This file is compiled as part of the `odin.dll` file. It contains the
// procs that `game.exe` will call, such as:
//
// game_init: Sets up the game state
// game_update: Run once per frame
// game_shutdown: Shuts down game and frees memory
// game_memory: Run just before a hot reload, so game.exe has a pointer to the
//		game's memory.
// game_hot_reloaded: Run after a hot reload so that the `g_mem` global variable
//		can be set to whatever pointer it was in the old DLL.

package game

// import "core:fmt"
// import "core:math/linalg"
import rl "vendor:raylib"

PixelWindowHeight :: 180

FILE_DIALOG_SIZE :: 1000
GameMemory :: struct {
	file_dialog_text_buffer: [FILE_DIALOG_SIZE + 1]u8,
}

g_mem: ^GameMemory

w, h: f32

game_camera :: proc() -> rl.Camera2D {
	w = f32(rl.GetScreenWidth())
	h = f32(rl.GetScreenHeight())

	return {zoom = h / PixelWindowHeight, target = {}, offset = {w / 2, h / 2}}
}

scaling: f32 = 2
ui_camera :: proc() -> rl.Camera2D {
	// return {zoom = f32(rl.GetScreenHeight()) / PixelWindowHeight}
	return {zoom = scaling}
}

input_box_loc: rl.Vector2 = {}
moving_input_box: bool
update :: proc() {
	// Update the width/height
	w = f32(rl.GetScreenWidth())
	h = f32(rl.GetScreenHeight())
	rl.SetMouseScale(1 / scaling, 1 / scaling)

	if rl.IsMouseButtonDown(.RIGHT) {
                input_box_loc = rl.GetMousePosition()
        }
}

draw :: proc() {
	rl.BeginDrawing()
        defer rl.EndDrawing()

	rl.ClearBackground(rl.BLACK)

	rl.BeginMode2D(ui_camera())
	rl.GuiTextInputBox(
		rl.Rectangle {
			x = input_box_loc.x,
			y = input_box_loc.y,
			width = (w / scaling) / 2,
			height = (h / scaling) / 2,
		},
		"Files",
		"File input box",
		"Button",
		cstring(rawptr(&g_mem.file_dialog_text_buffer)),
		FILE_DIALOG_SIZE,
		nil,
	)
	rl.EndMode2D()
}
