package game

import "core:strings"
import rl "vendor:raylib"

save_output :: proc() {
	image := rl.LoadImageFromTexture(g_mem.atlas_render_texture_target.texture)
	rl.ImageFlipVertical(&image)
	when ODIN_OS == .Windows {
		atlas_path :: "\\atlas.png"
	} else {
		atlas_path :: "/atlas.png"
	}
	output_path := strings.concatenate({g_mem.output_folder_path, atlas_path})
	cstring_output_path := strings.clone_to_cstring(output_path)
	rl.ExportImage(image, cstring_output_path)
}
