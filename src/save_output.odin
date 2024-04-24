package game

import "core:fmt"
import "core:strings"
import "core:os"
import "core:encoding/json"
import rl "vendor:raylib"


when ODIN_OS == .Windows {
	os_file_separator :: "\\"
} else {
	os_file_separator :: "/"
}

save_output :: proc() {
	if output_path, ok := g_mem.output_folder_path.(string); ok {
		if len(output_path) == 0 {
			fmt.println("Output path is empty!")
			return
		}

		image := rl.LoadImageFromTexture(g_mem.atlas_render_texture_target.texture)
		rl.ImageFlipVertical(&image)

		output_path := strings.concatenate({output_path, os_file_separator, "atlas.png"})
		cstring_output_path := strings.clone_to_cstring(output_path)

		rl.ExportImage(image, cstring_output_path)

		if metadata, ok := g_mem.atlas_metadata.([dynamic]SpriteAtlasMetadata); ok {
			if json_metadata, jok := json.marshal(metadata); jok == nil {
				os.write_entire_file(
					strings.concatenate({output_path, os_file_separator, "metadata.json"}),
					json_metadata,
				)
			} else {
                                fmt.println("Failed to marshall the atlas metadata to a json!")
                        }

                        // TODO(stefan): Think of a more generic alternative to just straight output to a odin file
                        // maybe supply a config.json that defines the start, end, line by line entry and enum format strings
                        // this way you can essentially support any language
			sb := generate_odin_enums_and_atlas_offsets_file_sb(metadata[:])
			odin_metadata := strings.to_string(sb)
			os.write_entire_file(
				strings.concatenate({output_path, os_file_separator, "metadata.odin"}),
				transmute([]byte)odin_metadata,
			)
		} else {
                        fmt.println("No metadata to export!")
                }

	} else {
		fmt.println("Output path is empty!")
	}
}
