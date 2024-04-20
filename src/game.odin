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

PackerSettings :: struct {
	pixel_padding_x_int: i32,
	pixel_padding_x:     f32,
	pixel_padding_y_int: i32,
	pixel_padding_y:     f32,
	padding_enabled:     bool,
	fix_pixel_bleeding:  bool,
	output_json:         bool,
	output_odin:         bool,
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
	// Packer settings
	packer_settings:                PackerSettings,
	atlas_render_texture_target:    rl.RenderTexture2D,
	atlas_render:                   bool,
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

	if g_mem.atlas_render {
		draw_screen_target()
	}
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
	rl.BeginTextureMode(g_mem.atlas_render_texture_target)
	defer rl.EndTextureMode()

	rl.ClearBackground(rl.WHITE)
	rl.DrawCircle(100, 100, 50, rl.GREEN)

	g_mem.atlas_render = false
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

	small_offset := 10 * scaling
	big_offset := 30 * scaling
	elements_height: f32 = 0

	rl.GuiPanel(left_half_rect, "Atlas Settings")
	elements_height += 25 * scaling

	rl.GuiLine({y = elements_height, width = left_half_rect.width}, "General Settings")
	elements_height += small_offset

	rl.GuiCheckBox(
		{x = small_offset, y = elements_height, width = small_offset, height = small_offset},
		"Fix pixel bleed",
		&g_mem.packer_settings.padding_enabled,
	)
	elements_height += small_offset * 2

	rl.GuiLine({y = elements_height, width = left_half_rect.width}, "Padding Settings")
	elements_height += small_offset

	rl.GuiCheckBox(
		{x = small_offset, y = elements_height, width = small_offset, height = small_offset},
		"Enable padding",
		&g_mem.packer_settings.fix_pixel_bleeding,
	)
	elements_height += small_offset * 2

	@(static)
	spinner_edit_mode: bool
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

	rl.GuiLine({y = elements_height, width = left_half_rect.width}, "Actions")
	elements_height += small_offset

	if rl.GuiButton(
		    {
			   x = small_offset,
			   y = elements_height,
			   width = left_half_rect.width / 2 - small_offset * 2,
			   height = small_offset,
		   },
		   "Pack",
	   ) {
                g_mem.atlas_render = true
	}
	elements_height += small_offset * 2


	if rl.GuiButton(
		    {
			   x = small_offset,
			   y = elements_height,
			   width = left_half_rect.width / 2 - small_offset * 2,
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
	rl.GuiDummyRec(preview_rect, "PREVIEW")
        preview_rect.x += 10; preview_rect.y += 10; preview_rect.height-=20;preview_rect.width-=20
	texture := &g_mem.atlas_render_texture_target.texture
	rl.DrawTexturePro(
		texture^,
		{width = auto_cast texture.width, height = auto_cast -texture.height},
		preview_rect,
		{0, 0},
		0,
		rl.WHITE,
	)
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
