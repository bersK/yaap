package game

import rl "vendor:raylib"

@(export)
game_update :: proc() -> bool {
	update()
	draw()
	return !rl.WindowShouldClose()
}

@(export)
game_init_window :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(1400, 800, "YAAP - Yet Another Atlas Packer, Powered by Raylib & Odin")
	rl.SetWindowPosition(200, 200)
	rl.SetWindowMinSize(1400, 800)
}

@(export)
game_init :: proc() {
	g_mem = new(GameMemory)

	g_mem^ = GameMemory{}

	game_hot_reloaded(g_mem)

	current_monitor := rl.GetCurrentMonitor()
	g_mem.monitor_info = MonitorInformation {
		max_width  = auto_cast rl.GetMonitorWidth(current_monitor),
		max_height = auto_cast rl.GetMonitorHeight(current_monitor),
	}

	g_mem.window_info = WindowInformation {
		w = 1280,
		h = 720,
	}

	g_mem.atlas_render_texture_target = rl.LoadRenderTexture(2048, 2048)

	rl.SetTargetFPS(rl.GetMonitorRefreshRate(current_monitor))
	rl.GuiLoadStyle("./styles/style_candy.rgs")
}

@(export)
game_shutdown :: proc() {
	free(g_mem)
}

@(export)
game_shutdown_window :: proc() {
	rl.CloseWindow()
}

@(export)
game_memory :: proc() -> rawptr {
	return g_mem
}

@(export)
game_memory_size :: proc() -> int {
	return size_of(GameMemory)
}

@(export)
game_hot_reloaded :: proc(mem: rawptr) {
	g_mem = (^GameMemory)(mem)
	rl.GuiLoadStyle("./styles/style_candy.rgs")
}

@(export)
game_force_reload :: proc() -> bool {
	return rl.IsKeyPressed(.F5)
}

@(export)
game_force_restart :: proc() -> bool {
	return rl.IsKeyPressed(.F6)
}
