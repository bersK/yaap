package tinyfiledialogs

import "core:c"

when ODIN_OS == .Windows {
	foreign import lib {"tinyfiledialogs.lib", "system:comdlg32.lib", "system:Ole32.lib"}
} else when ODIN_OS == .Linux || ODIN_OS == .Darwin {
	foreign import lib "libtinyfiledialogs.a"
}

foreign lib {
	@(link_name = "tinyfd_notifyPopup")
	notify_popup :: proc(title, message, icon_type: cstring) -> c.int ---

	@(link_name = "tinyfd_messageBox")
	message_box :: proc(title, message, dialog_type, icon_type: cstring, default_button: c.int) -> c.int ---

	@(link_name = "tinyfd_inputBox")
	input_box :: proc(title, message, default_input: cstring) -> [^]c.char ---

	@(link_name = "tinyfd_saveFileDialog")
	save_file_dialog :: proc(title, default_path: cstring, pattern_count: c.int, patterns: [^]cstring, file_desc: cstring) -> [^]c.char ---

	@(link_name = "tinyfd_openFileDialog")
	open_file_dialog :: proc(title, default_path: cstring, pattern_count: c.int, patterns: [^]cstring, file_desc: cstring, allow_multi: c.int) -> [^]c.char ---

	@(link_name = "tinyfd_selectFolderDialog")
	select_folder_dialog :: proc(title, default_path: cstring) -> [^]c.char ---

	@(link_name = "tinyfd_colorChooser")
	color_chooser :: proc(title, default_hex_rgb: cstring, default_rgb, result_rgb: [3]byte) -> [^]c.char ---
}
