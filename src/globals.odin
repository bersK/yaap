
package game

import rl "vendor:raylib"

PixelWindowHeight :: 180
FILE_DIALOG_SIZE :: 1000

scaling: f32 = 2
w, h: f32

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
	SaveFileAs,
}

PackerSettings :: struct {
	atlas_size_x:        i32,
	atlas_size_y:        i32,
	pixel_padding_x_int: i32,
	pixel_padding_y_int: i32,
	padding_enabled:     bool,
	output_json:         bool,
	output_odin:         bool,
}

GameMemory :: struct {
	file_dialog_text_buffer:        [FILE_DIALOG_SIZE + 1]u8,
	is_packing_whole_source_folder: bool,
	should_open_file_dialog:        bool,
	window_info:                    WindowInformation,
	monitor_info:                   MonitorInformation,
	// Where the output files will be written (atlas.png, json output, etc)
	output_folder_path:             Maybe(string),
	// If files were chosen as input - their paths
	source_location_to_pack:        Maybe(string),
	// If a folder was chosen as input - the path
	source_files_to_pack:           Maybe([]string),
	// What type of file dialog to open
	source_location_type:           FileDialogType,
	// Packer settings
	packer_settings:                PackerSettings,
	atlas_render_texture_target:    rl.RenderTexture2D,
	atlas_checked_background:       rl.RenderTexture2D,
	should_render_atlas:            bool,
	atlas_render_has_preview:       bool,
	atlas_render_size:              i32,
	atlas_metadata:                 Maybe([dynamic]SpriteAtlasMetadata),
}
