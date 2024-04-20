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
import "core:strings"
import rl "vendor:raylib"

import diag "dialog"

PixelWindowHeight :: 180

/*
	`SourceFilesPicker` // Screen 1: Shows the file dialog box, meant for the user to choose the source files/folder
	`OutputLocationPicker` // Screen 2: Shows the file dialog box, meant for the user to choose the output file name & location
	`PackSettingsAndPreview` Screen 3: Shows settings about the packing operations, `save` & `save as` button
	`SaveToOutputPicker` // Screen 4: After clicking the `save as` button on screen 3, ask the user for a new location & name and save the file
*/

AppScreen :: enum {
	SourceFilesPicker,
	OutputLocationPicker,
	PackSettingsAndPreview,
	SaveToOutputPicker,
}

WindowInformation :: struct {
	w:             f32,
	h:             f32,
	width_scaled:  f32,
	height_scaled: f32,
}

MonitorInformation :: struct {
	max_width:  f32,
	max_height: f32,
}

FileDialogType :: enum {
	SourceFiles,
	SourceFolder,
	OutputFolder,
	Exit,
}


FILE_DIALOG_SIZE :: 1000
GameMemory :: struct {
	file_dialog_text_buffer:        [FILE_DIALOG_SIZE + 1]u8,
	is_packing_whole_source_folder: bool,
	should_open_file_dialog:        bool,
	window_info:                    WindowInformation,
	monitor_info:                   MonitorInformation,
	// atlas packer state
	app_screen:                     AppScreen,
	// Where the output files will be written (atlas.png, json output, etc)
	output_path_set:                bool,
	output_folder_path:             string,
	// If files were chosen as input - their paths
	input_path_set:                 bool,
	source_location_to_pack:        string,
	// If a folder was chosen as input - the path
	input_files_set:                bool,
	source_files_to_pack:           []string,
	// What type of file dialog to open
	source_location_type:           FileDialogType,
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
	return {zoom = scaling}
}

input_box_loc: rl.Vector2 = {}
moving_input_box: bool
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

	update_screen()
}

draw :: proc() {
	rl.BeginDrawing()
	defer rl.EndDrawing()

	rl.ClearBackground(rl.BLACK)

	draw_screen_ui()

	draw_screen_target()
}

update_screen :: proc() {
	if (g_mem.input_files_set || g_mem.input_path_set) {
		if !g_mem.output_path_set {
			g_mem.app_screen = .OutputLocationPicker
		} else {
			g_mem.app_screen = .PackSettingsAndPreview
		}
	} else {
		g_mem.app_screen = .SourceFilesPicker
	}

	switch g_mem.app_screen {
	case .SourceFilesPicker:
		fallthrough
	case .OutputLocationPicker:
		fallthrough
	case .SaveToOutputPicker:
		if g_mem.should_open_file_dialog {
			open_file_dialog_and_store_output_paths()
		}
	case .PackSettingsAndPreview:
	}
}

draw_screen_ui :: proc() {
	rl.BeginMode2D(ui_camera())
	defer rl.EndMode2D()

	switch g_mem.app_screen {
	case .SourceFilesPicker:
		fallthrough
	case .OutputLocationPicker:
		fallthrough
	case .SaveToOutputPicker:
		draw_and_handle_source_files_logic()
	case .PackSettingsAndPreview:
		draw_atlas_settings_and_preview()
	}
}

draw_screen_target :: proc() {
	rl.BeginMode2D(ui_camera())
	defer rl.EndMode2D()

}
draw_atlas_settings_and_preview :: proc() {
	left_half_rect := rl.Rectangle {
		0,
		0,
		auto_cast g_mem.window_info.width_scaled / 2,
		auto_cast g_mem.window_info.height_scaled,
	}
	right_half_rect := rl.Rectangle {
		auto_cast g_mem.window_info.width_scaled / 2,
		0,
		auto_cast g_mem.window_info.width_scaled / 2,
		auto_cast g_mem.window_info.height_scaled,
	}
	rl.DrawRectangleRec(left_half_rect, rl.WHITE)
	rl.DrawRectangleRec(right_half_rect, rl.MAROON)

	// font := rl.GuiGetFont()
	// text_size := rl.MeasureTextEx(font, "Atlas Packer Settings", auto_cast font.baseSize / scaling, 1)

        small_offset := 10 * scaling
	elements_height: f32 = 0
	rl.GuiLabel(
		rl.Rectangle{x = small_offset, y = 0, width = 100 * scaling, height = 25 * scaling},
		"Atlas Packer Settings",
	)
	elements_height += 25 * scaling
	rl.GuiLine({y = elements_height, width = left_half_rect.width}, "Packer Settings")
	elements_height += small_offset
	rl.GuiLine({y = elements_height, width = left_half_rect.width}, "Save Settings")
	elements_height += small_offset
	if rl.GuiButton(
		    {
			   x = small_offset,
			   y = elements_height,
			   width = left_half_rect.width / 2 - small_offset * 2,
			   height = 25 * scaling,
		   },
		   "Save",
	   ) {

	}
	if rl.GuiButton(
		    {
			   x = left_half_rect.width / 2,
			   y = elements_height,
			   width = left_half_rect.width / 2 - small_offset,
			   height = 25 * scaling,
		   },
		   "Save To...",
	   ) {

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

draw_and_handle_source_files_logic :: proc() {
	switch g_mem.app_screen {
	case .SourceFilesPicker:
		result := rl.GuiTextInputBox(
			rl.Rectangle{width = (w / scaling), height = (h / scaling)},
			"Files",
			"File input box",
			"Open Source Files;Open Source Folder",
			cstring(rawptr(&g_mem.file_dialog_text_buffer)),
			FILE_DIALOG_SIZE,
			nil,
		)
		if result != -1 {
			file_dialg_type: FileDialogType
			if result == 1 || result == 2 {
				file_dialg_type = .SourceFiles if result == 1 else .SourceFolder
			} else if result == 0 {
				file_dialg_type = .Exit
			}
			handle_source_file_logic(file_dialg_type)
			fmt.println("result: ", result)
		}
	case .OutputLocationPicker:
		result := rl.GuiTextInputBox(
			rl.Rectangle{width = (w / scaling), height = (h / scaling)},
			"Files",
			"Output Folder",
			"Choose Output Folder",
			cstring(rawptr(&g_mem.file_dialog_text_buffer)),
			FILE_DIALOG_SIZE,
			nil,
		)
		if result != -1 {
			file_dialg_type: FileDialogType = .OutputFolder if result == 1 else .Exit
			handle_source_file_logic(file_dialg_type)
			fmt.println("result: ", result)
		}
	case .SaveToOutputPicker:
		result := rl.GuiTextInputBox(
			rl.Rectangle{width = (w / scaling), height = (h / scaling)},
			"Files",
			"Output Folder",
			"Choose Output Folder",
			cstring(rawptr(&g_mem.file_dialog_text_buffer)),
			FILE_DIALOG_SIZE,
			nil,
		)
		if result != -1 {
			file_dialg_type: FileDialogType = .SourceFolder if result == 1 else .Exit
			handle_source_file_logic(file_dialg_type)
			fmt.println("result: ", result)
		}
	case .PackSettingsAndPreview:
		draw_packer_and_settings()
	}
}

draw_packer_and_settings :: proc() {

}

handle_source_file_logic :: proc(picker_type: FileDialogType) {
	switch picker_type {
	case .Exit:
		g_mem.should_open_file_dialog = false
		rl.CloseWindow()
	case .SourceFiles:
		fallthrough
	case .SourceFolder:
		fallthrough
	case .OutputFolder:
		g_mem.source_location_type = picker_type
		g_mem.should_open_file_dialog = true
	}
}
