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

GameMemory :: struct {}

g_mem: ^GameMemory

game_camera :: proc() -> rl.Camera2D {
	w := f32(rl.GetScreenWidth())
	h := f32(rl.GetScreenHeight())

	return {zoom = h / PixelWindowHeight, target = {}, offset = {w / 2, h / 2}}
}

ui_camera :: proc() -> rl.Camera2D {
	return {zoom = f32(rl.GetScreenHeight()) / PixelWindowHeight}
}

update :: proc() {
}

draw :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)

	rl.BeginMode2D(game_camera())
	// rl.DrawRectangleV(g_mem.player_pos, {4, 8}, rl.WHITE)
	rl.DrawRectangleV({20, 20}, {10, 20}, rl.RED)
	rl.EndMode2D()

	rl.BeginMode2D(ui_camera())
	// rl.DrawText(
	// 	fmt.ctprintf("some_number: %v\nplayer_pos: %v", g_mem.some_number, g_mem.player_pos),
	// 	5,
	// 	5,
	// 	8,
	// 	rl.WHITE,
	// )
	rl.EndMode2D()

	rl.EndDrawing()
}