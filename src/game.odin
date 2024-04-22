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

import "core:fmt"
import "core:math"
import "core:strings"
import rl "vendor:raylib"

import diag "dialog"

g_mem: ^GameMemory

game_camera :: proc() -> rl.Camera2D {
	w = f32(rl.GetScreenWidth())
	h = f32(rl.GetScreenHeight())

	return {zoom = h / PixelWindowHeight, target = {}, offset = {w / 2, h / 2}}
}

ui_camera :: proc() -> rl.Camera2D {
	return {zoom = scaling}
}

update :: proc() {
	// Update the width/height
	win_info := &g_mem.window_info
	win_info.w = f32(rl.GetScreenWidth())
	win_info.h = f32(rl.GetScreenHeight())
	win_info.height_scaled = win_info.h / scaling
	win_info.width_scaled = win_info.w / scaling
	w = win_info.w
	h = win_info.h

	// Update the virtual mouse position (needed for GUI interaction to work properly for instance)
	rl.SetMouseScale(1 / scaling, 1 / scaling)

	if g_mem.should_open_file_dialog {
		open_file_dialog_and_store_output_paths()
	}
}

draw :: proc() {
	rl.BeginDrawing()
	defer rl.EndDrawing()

	rl.ClearBackground(rl.BLACK)

	draw_screen_ui()

	if g_mem.should_render_atlas {
		draw_screen_target()
	}

	free_all(context.temp_allocator)
}

draw_screen_ui :: proc() {
	rl.BeginMode2D(ui_camera())
	defer rl.EndMode2D()

	draw_atlas_settings_and_preview()
}

draw_screen_target :: proc() {
	atlas_render_target := &g_mem.atlas_render_texture_target

	rl.BeginTextureMode(atlas_render_target^)
	defer rl.EndTextureMode()

	atlas_entries: [dynamic]AtlasEntry
	delete(atlas_entries)

	if g_mem.input_path_set {
		unmarshall_aseprite_dir(g_mem.output_folder_path, &atlas_entries)
	} else if g_mem.input_files_set {
		unmarshall_aseprite_files(g_mem.source_files_to_pack, &atlas_entries)
	} else {
		fmt.println("No source folder or files set! Can't pack the void!!!")
		g_mem.should_render_atlas = false
		return
	}

	atlas: rl.Image = rl.GenImageColor(g_mem.atlas_render_size, g_mem.atlas_render_size, rl.BLANK)
	// defer rl.UnloadImage(atlas)

	padding_x :=
		g_mem.packer_settings.pixel_padding_x_int if g_mem.packer_settings.padding_enabled else 0
	padding_y :=
		g_mem.packer_settings.pixel_padding_y_int if g_mem.packer_settings.padding_enabled else 0
	pack_atlas_entries(atlas_entries[:], &atlas, padding_x, padding_y)

	// OpenGL's Y buffer is flipped
	rl.ImageFlipVertical(&atlas)
	// rl.UnloadTexture(atlas_render_target.texture)
        fmt.println("Packed everything!")
	atlas_render_target.texture = rl.LoadTextureFromImage(atlas)

	g_mem.should_render_atlas = false
	g_mem.atlas_render_has_preview = true
}

draw_atlas_settings_and_preview :: proc() {
	left_half_rect := rl.Rectangle {
		x      = 0,
		y      = 0,
		width  = auto_cast g_mem.window_info.width_scaled / 3,
		height = auto_cast g_mem.window_info.height_scaled,
	}
	right_half_rect := rl.Rectangle {
		x      = auto_cast g_mem.window_info.width_scaled / 3,
		y      = 0,
		width  = auto_cast (g_mem.window_info.width_scaled / 3) * 2,
		height = auto_cast g_mem.window_info.height_scaled,
	}
	rl.DrawRectangleRec(left_half_rect, rl.WHITE)
	rl.DrawRectangleRec(right_half_rect, rl.MAROON)

	@(static)
	spinner_edit_mode: bool

	small_offset := 10 * scaling
	big_offset := 30 * scaling
	elements_height: f32 = 0

	rl.GuiPanel(left_half_rect, "Atlas Settings")
	elements_height += small_offset / 2

	@(static)
	SettingsDropBoxEditMode: bool
	@(static)
	SettingsDropdownBoxActive: i32

	elements_height += small_offset + 5 * scaling

	rl.GuiLabel(
		{x = small_offset, y = elements_height, width = left_half_rect.width},
		"Atlas Size",
	)
	elements_height += small_offset / 2

	@(static)
	DropdownBox000EditMode: bool
	@(static)
	DropdownBox000Active: i32

	dropdown_rect := rl.Rectangle {
		x      = small_offset,
		y      = elements_height,
		width  = left_half_rect.width - small_offset * 2,
		height = small_offset,
	}

	// Because we want to render this ontop of everything else, we can just 'defer' it at the end of the draw function
	defer {
		if DropdownBox000EditMode {rl.GuiLock()}

		if rl.GuiDropdownBox(
			   dropdown_rect,
			   "256x;512x;1024x;2048x;4096x",
			   &DropdownBox000Active,
			   DropdownBox000EditMode,
		   ) {
			DropdownBox000EditMode = !DropdownBox000EditMode
			fmt.println(DropdownBox000Active)
			g_mem.atlas_render_size = 256 * auto_cast math.pow(2, f32(DropdownBox000Active))
		}
		rl.GuiUnlock()
	}
	elements_height += small_offset * 2


	// General Options
	if SettingsDropdownBoxActive == 0 {
		padding_settings_y := elements_height
		{
			defer rl.GuiGroupBox(
				 {
					x = small_offset / 2,
					y = padding_settings_y,
					width = left_half_rect.width - small_offset,
					height = elements_height - padding_settings_y,
				},
				"Padding Settings",
			)
			elements_height += small_offset

			rl.GuiCheckBox(
				 {
					x = small_offset,
					y = elements_height,
					width = small_offset,
					height = small_offset,
				},
				"  Enable padding",
				&g_mem.packer_settings.fix_pixel_bleeding,
			)
			elements_height += small_offset * 2

			if (rl.GuiSpinner(
					    {
						   x = small_offset,
						   y = elements_height,
						   width = big_offset * 2,
						   height = small_offset,
					   },
					   "",
					   &g_mem.packer_settings.pixel_padding_x_int,
					   0,
					   10,
					   spinner_edit_mode,
				   )) >
			   0 {spinner_edit_mode = !spinner_edit_mode}
			rl.GuiLabel(
				 {
					x = (small_offset * 2) + big_offset * 2,
					y = elements_height,
					width = big_offset,
					height = small_offset,
				},
				"Padding X",
			)
			elements_height += small_offset * 2

			if (rl.GuiSpinner(
					    {
						   x = small_offset,
						   y = elements_height,
						   width = big_offset * 2,
						   height = small_offset,
					   },
					   "",
					   &g_mem.packer_settings.pixel_padding_y_int,
					   0,
					   10,
					   spinner_edit_mode,
				   )) >
			   0 {spinner_edit_mode = !spinner_edit_mode}
			rl.GuiLabel(
				 {
					x = (small_offset * 2) + big_offset * 2,
					y = elements_height,
					width = big_offset,
					height = small_offset,
				},
				"Padding Y",
			)
			elements_height += small_offset * 2

		}
		elements_height += small_offset

		// rl.GuiLine({y = elements_height, width = left_half_rect.width}, "Actions")
		// elements_height += small_offset

		actions_label_y := elements_height
		{
			defer rl.GuiGroupBox(
				 {
					x = small_offset / 2,
					y = actions_label_y,
					width = left_half_rect.width - small_offset,
					height = elements_height - actions_label_y,
				},
				"Actions",
			)
			elements_height += small_offset

			if rl.GuiButton(
				    {
					   x = small_offset,
					   y = elements_height,
					   width = left_half_rect.width / 2 - small_offset,
					   height = small_offset,
				   },
				   "Pick Source(s)",
			   ) {
				g_mem.should_open_file_dialog = true
				g_mem.source_location_type = .SourceFiles
			}
			if rl.GuiButton(
				    {
					   x = left_half_rect.width / 2,
					   y = elements_height,
					   width = left_half_rect.width / 2 - small_offset,
					   height = small_offset,
				   },
				   "Pick Output",
			   ) {
				g_mem.should_open_file_dialog = true
				g_mem.source_location_type = .OutputFolder
			}
			elements_height += small_offset * 2


			if rl.GuiButton(
				    {
					   x = small_offset,
					   y = elements_height,
					   width = left_half_rect.width / 2 - small_offset,
					   height = small_offset,
				   },
				   "Pack Atlas",
			   ) {
				g_mem.should_render_atlas = true
			}
			if rl.GuiButton(
				    {
					   x = left_half_rect.width / 2,
					   y = elements_height,
					   width = left_half_rect.width / 2 - small_offset,
					   height = small_offset,
				   },
				   "Clear Atlas",
			   ) {
				g_mem.atlas_render_has_preview = false
			}
			elements_height += small_offset * 2

			if rl.GuiButton(
				    {
					   x = small_offset,
					   y = elements_height,
					   width = left_half_rect.width / 2 - small_offset,
					   height = small_offset,
				   },
				   "Save",
			   ) {
				save_output()
			}
			if rl.GuiButton(
				    {
					   x = left_half_rect.width / 2,
					   y = elements_height,
					   width = left_half_rect.width / 2 - small_offset,
					   height = small_offset,
				   },
				   "Save To...",
			   ) {
			}
			elements_height += small_offset * 2
		}

	}

	// Packing Options
	if SettingsDropdownBoxActive == 1 {

		@(static)
		active_tab: i32
		tabs: []cstring = {"One", "Two", "Three"}
		rl.GuiTabBar(
			{x = small_offset, y = elements_height, width = 100, height = small_offset},
			&tabs[0],
			auto_cast len(tabs),
			&active_tab,
		)
	}

	// Save Options
	if SettingsDropdownBoxActive == 2 {

	}

	elements_height = 0
	rl.GuiPanel(right_half_rect, "Atlas Preview")
	short_edge := min(
		right_half_rect.height - big_offset * 1.5,
		right_half_rect.width - big_offset * 1.5,
	)
	preview_rect := rl.Rectangle {
		x      = (right_half_rect.width / 2 + right_half_rect.x) - (short_edge / 2),
		y      = (right_half_rect.height / 2 + right_half_rect.y) - (short_edge / 2),
		width  = short_edge,
		height = short_edge,
	}
	if !g_mem.atlas_render_has_preview {
		rl.GuiDummyRec(preview_rect, "PREVIEW")
	} else {
		// rl.DrawRectangleRec(preview_rect, rl.WHITE)
		bg_texture := g_mem.atlas_checked_background.texture
		rl.DrawTexturePro(
			bg_texture,
			{width = auto_cast bg_texture.width, height = auto_cast bg_texture.height},
			preview_rect,
			{},
			0,
			rl.WHITE,
		)
		// preview_rect.x +=
		// 10;preview_rect.y += 10;preview_rect.height -= 20;preview_rect.width -= 20
		atlas_texture := g_mem.atlas_render_texture_target.texture
		rl.DrawTexturePro(
			atlas_texture,
			{width = auto_cast atlas_texture.width, height = auto_cast -atlas_texture.height},
			preview_rect,
			{0, 0},
			0,
			rl.WHITE,
		)
	}
}

open_file_dialog_and_store_output_paths :: proc() {
	if g_mem.source_location_type == .SourceFiles {
		files := cstring(
			diag.open_file_dialog(
				"Select source files",
				cstring(&g_mem.file_dialog_text_buffer[0]),
				0,
				nil,
				"",
				1,
			),
		)

		source_files_to_pack := strings.clone_from_cstring(files, context.allocator)
		// File dialog returns an array of path(s), separated by a '|'
		g_mem.source_files_to_pack = strings.split(source_files_to_pack, "|")
		g_mem.input_files_set = (len(source_files_to_pack) > 0)

		fmt.println(g_mem.source_files_to_pack)
	}
	if g_mem.source_location_type == .SourceFolder {
		file := cstring(
			diag.select_folder_dialog(
				"Select source folder",
				cstring(&g_mem.file_dialog_text_buffer[0]),
			),
		)
		g_mem.source_location_to_pack = strings.clone_from_cstring(file)
		g_mem.input_path_set = (len(file) > 0)
		fmt.println(g_mem.source_location_to_pack)
	}
	if g_mem.source_location_type == .OutputFolder {
		file := cstring(
			diag.select_folder_dialog(
				"Select source folder",
				cstring(&g_mem.file_dialog_text_buffer[0]),
			),
		)
		g_mem.output_folder_path = strings.clone_from_cstring(file)

		g_mem.output_path_set = (len(file) > 0)
		fmt.println(g_mem.output_folder_path)
	}

	g_mem.should_open_file_dialog = false
}
