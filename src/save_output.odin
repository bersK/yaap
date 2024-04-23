package game

import "core:strings"
import "core:fmt"
import rl "vendor:raylib"

when ODIN_OS == .Windows {
        atlas_path :: "\\atlas.png"
} else {
        atlas_path :: "/atlas.png"
}

save_output :: proc() {
	if output_path, ok := g_mem.output_folder_path.(string); ok {
                if len(output_path) == 0 {
                        fmt.println("Output path is empty!")
                        return
                }

		image := rl.LoadImageFromTexture(g_mem.atlas_render_texture_target.texture)
		rl.ImageFlipVertical(&image)
		output_path := strings.concatenate({output_path, atlas_path})
		cstring_output_path := strings.clone_to_cstring(output_path)
		rl.ExportImage(image, cstring_output_path)
	}
}
