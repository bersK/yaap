package game

import ase "./aseprite"
import "core:fmt"
import "core:os"
import fp "core:path/filepath"
import "core:slice"
import "core:strings"
import rl "vendor:raylib"
import stbrp "vendor:stb/rect_pack"

CellData :: struct {
	layer_index: u16,
	opacity:     u8,
	frame_index: i32,
	img:         rl.Image,
}

AtlasEntry :: struct {
	path:             string,
	cells:            [dynamic]CellData,
	frames:           i32,
	layer_names:      [dynamic]string,
	layer_cell_count: [dynamic]i32,
}

SpriteAtlasMetadata :: struct {
	name:     string,
	location: [2]i32,
	size:     [2]i32,
}

unmarshall_aseprite_dir :: proc(
	path: string,
	atlas_entries: ^[dynamic]AtlasEntry,
	alloc := context.allocator,
) {
	if len(path) == 0 do return

	if dir_fd, err := os.open(path, os.O_RDONLY); err == os.ERROR_NONE {
		fis: []os.File_Info
		if fis, err = os.read_dir(dir_fd, -1); err == os.ERROR_NONE {
			unmarshall_aseprite_files_file_info(fis, atlas_entries, alloc)
		}
	} else {
		fmt.println("Couldn't open folder: ", path)
	}
}

unmarshall_aseprite_files_file_info :: proc(
	files: []os.File_Info,
	atlas_entries: ^[dynamic]AtlasEntry,
	alloc := context.allocator,
) {
	if len(files) == 0 do return

	paths := make([]string, len(files), alloc)
	defer delete(paths)

	for f, fi in files {
		paths[fi] = f.fullpath
	}

	unmarshall_aseprite_files(paths[:], atlas_entries, alloc)

}

unmarshall_aseprite_files :: proc(
	file_paths: []string,
	atlas_entries: ^[dynamic]AtlasEntry,
	alloc := context.allocator,
) {
	if len(file_paths) == 0 do return

	aseprite_document: ase.Document
	for file in file_paths {
		extension := fp.ext(file)
		if extension != ".aseprite" do continue

		fmt.println("Unmarshalling file: ", file)
		ase.unmarshal_from_filename(file, &aseprite_document, alloc)
		atlas_entry := atlas_entry_from_compressed_cells(aseprite_document)
		atlas_entry.path = file

		append(atlas_entries, atlas_entry)
	}
}

/*
        Goes through all the chunks in an aseprite document & copies the `Com_Image_Cel` cells in a separate image
*/
atlas_entry_from_compressed_cells :: proc(document: ase.Document) -> (atlas_entry: AtlasEntry) {
	atlas_entry.frames = auto_cast len(document.frames)
	fmt.println("N Frames: ", len(document.frames))
	// note(stefan): Since the expected input for the program is multiple files containing a single sprite
	// it's probably a safe assumption most of the files will be a single layer with 1 or more frames
	// which means we can first prod the file for information about how many frames are there and
	// allocate a slice that is going to be [Frames X Layers]CellData.
	// which would allow us to gain an already sorted list of sprites if we iterate all frames of a single layer
	// instead of iterating all layers for each frame
	// might be even quicker to first get that information an allocate at once the amount of cells we need
	for frame, frameIdx in document.frames {
		fmt.printfln("Frame_{0} Chunks: ", frameIdx, len(frame.chunks))
		for chunk in frame.chunks {
			if cel_chunk, ok := chunk.(ase.Cel_Chunk); ok {
				cel_img, ci_ok := cel_chunk.cel.(ase.Com_Image_Cel)
				if !ci_ok do continue

				fmt.println(cel_chunk.layer_index)

				cell := CellData {
					img = rl.Image {
						data = rawptr(&cel_img.pixel[0]),
						width = auto_cast cel_img.width,
						height = auto_cast cel_img.height,
						format = .UNCOMPRESSED_R8G8B8A8,
					},
					frame_index = auto_cast frameIdx,
					opacity = cel_chunk.opacity_level,
					layer_index = cel_chunk.layer_index,
				}

				append(&atlas_entry.cells, cell)
			}

			if layer_chunk, ok := chunk.(ase.Layer_Chunk); ok {
				fmt.println("Layer chunk: ", layer_chunk)
				append(&atlas_entry.layer_names, layer_chunk.name)
			}
		}
	}

	slice.sort_by(atlas_entry.cells[:], proc(i, j: CellData) -> bool {
		return i.layer_index < j.layer_index
	})

	return
}

/*
        Takes in a slice of entries, an output texture and offsets (offset_x/y)
*/
pack_atlas_entries :: proc(
	entries: []AtlasEntry,
	atlas: ^rl.Image,
	offset_x: i32,
	offset_y: i32,
	allocator := context.allocator,
) -> [dynamic]SpriteAtlasMetadata {
	assert(atlas.width != 0, "Atlas width shouldn't be 0!")
	assert(atlas.height != 0, "Atlas height shouldn't be 0!")

	all_cell_images := make([dynamic]rl.Image, allocator) // it's fine to store it like this, rl.Image just stores a pointer to the data
	for &entry in entries {
		for cell in entry.cells {
			append(&all_cell_images, cell.img)
		}
		entry.layer_cell_count = make([dynamic]i32, len(entry.cells), allocator)
	}

	num_entries := len(all_cell_images)
	nodes := make([]stbrp.Node, num_entries, allocator)
	rects := make([]stbrp.Rect, num_entries, allocator)

	EntryAndCell :: struct {
		entry:         ^AtlasEntry,
		cell_of_entry: ^CellData,
	}
	rect_idx_to_entry_and_cell := make(map[int]EntryAndCell, 100, allocator)

	// Set the custom IDs
	cellIdx: int
	for &entry, entryIdx in entries {
		for &cell in entry.cells {
			// I can probably infer this information with just the id of the rect but I'm being lazy right now
			map_insert(&rect_idx_to_entry_and_cell, cellIdx, EntryAndCell{&entry, &cell})
			rects[cellIdx].id = auto_cast entryIdx
			cellIdx += 1

			entry.layer_cell_count[cell.layer_index] += 1
		}
	}

	for cell_image, cell_index in all_cell_images {
		entry_stb_rect := &rects[cell_index]
		entry_stb_rect.w = stbrp.Coord(cell_image.width + offset_x)
		entry_stb_rect.h = stbrp.Coord(cell_image.height + offset_y)
	}

	ctx: stbrp.Context
	stbrp.init_target(&ctx, atlas.width, atlas.height, &nodes[0], i32(num_entries))
	res := stbrp.pack_rects(&ctx, &rects[0], i32(num_entries))
	if res == 1 {
		fmt.println("Packed everything successfully!")
		fmt.printfln("Rects: {0}", rects[:])
	} else {
		fmt.println("Failed to pack everything!")
	}

	for rect, rectIdx in rects {
		entry_and_cell := rect_idx_to_entry_and_cell[auto_cast rectIdx]
		cell := entry_and_cell.cell_of_entry

		src_rect := rl.Rectangle {
			x      = 0,
			y      = 0,
			width  = auto_cast cell.img.width,
			height = auto_cast cell.img.height,
		}

		dst_rect := rl.Rectangle {
			auto_cast rect.x + auto_cast offset_x,
			auto_cast rect.y + auto_cast offset_y,
			auto_cast cell.img.width,
			auto_cast cell.img.height,
		}

		// note(stefan): drawing the sprite in the atlas in the packed coordinates
		rl.ImageDraw(atlas, cell.img, src_rect, dst_rect, rl.WHITE)

		fmt.printfln("Src rect: {0}\nDst rect:{1}", src_rect, dst_rect)
	}

	metadata := make([dynamic]SpriteAtlasMetadata, allocator)
	for rect, rectIdx in rects {
		entry_and_cell := rect_idx_to_entry_and_cell[auto_cast rectIdx]
		entry := entry_and_cell.entry
		cell := entry_and_cell.cell_of_entry

		cell_name: string
		if entry.layer_cell_count[cell.layer_index] > 1 {
			cell_name = fmt.aprintf(
				"{0}_%d",
				entry.layer_names[cell.layer_index],
				cell.frame_index,
				allocator,
			)
		} else {
			cell_name = entry.layer_names[cell.layer_index]
		}
		cell_metadata := SpriteAtlasMetadata {
			name     = cell_name,
			location =  {
				auto_cast rect.x + auto_cast offset_x,
				auto_cast rect.y + auto_cast offset_y,
			},
			size     = {auto_cast cell.img.width, auto_cast cell.img.height},
		}
		append(&metadata, cell_metadata)
	}

	return metadata
}

SourceCodeGeneratorMetadata :: struct {
	file_defines:     struct {
		top:    string,
		bottom: string,
	},
	custom_data_type: struct {
		name:             string,
		type_declaration: string, // contains one param: custom_data_type.name + the rest of the type declaration like braces of the syntax & the type members
	},
	enum_data:        struct {
		name:       string,
		begin_line: string, // contains one params: enum_data.name
		entry_line: string,
		end_line:   string,
	},
	array_data:       struct {
		name:       string,
		type:       string,
		begin_line: string, // array begin line contains 2 params in the listed order: array.name, array.type
		entry_line: string, // array entry contains 5 params in the listed order: cell.name, cell.location.x, cell.location.y, cell.size.x, cell.size.y,
		end_line:   string,
	},
}

odin_source_generator_metadata := SourceCodeGeneratorMetadata {
	file_defines = {top = "package atlas_bindings\n\n", bottom = ""},
	custom_data_type =  {
		name = "AtlasRect",
		type_declaration = "%v :: struct {{ x, y, w, h: i32 }}\n\n",
	},
	enum_data =  {
		name = "AtlasEnum",
		begin_line = "%v :: enum {{\n",
		entry_line = "\t%s,\n",
		end_line = "}\n\n",
	},
	array_data =  {
		name = "ATLAS_SPRITES",
		type = "[]AtlasRect",
		begin_line = "%v := %v {{\n",
		entry_line = "\t.%v = {{ x = %v, y = %v, w = %v, h = %v }},\n",
		end_line = "}\n\n",
	},
}


// cpp_source_generator_metadata := SourceCodeGeneratorMetadata {
// 	file_defines = {top = "package atlas_bindings\n\n", bottom = ""},
// 	custom_data_type =  {
// 		name = "AtlasRect",
// 		type_declaration = "%v :: struct {{ x, y, w, h: i32 }}\n\n",
// 	},
// 	enum_data =  {
// 		name = "AtlasEnum",
// 		begin_line = "%v :: enum {{\n",
// 		entry_line = "\t%s,\n",
// 		end_line = "}\n\n",
// 	},
// 	array_data =  {
// 		name = "ATLAS_SPRITES",
// 		type = "[]AtlasRect",
// 		begin_line = "%v := %v {{\n",
// 		entry_line = "\t.%v = {{ x = %v, y = %v, w = %v, h = %v }},\n",
// 		end_line = "}\n\n",
// 	},
// }

/*
        Generates a barebones file with the package name "atlas_bindings",
        the file contains an array of offsets, indexed by an enum.
        The enum has unique names
*/
generate_odin_enums_and_atlas_offsets_file_sb :: proc(
	metadata: []SpriteAtlasMetadata,
	alloc := context.allocator,
) -> strings.Builder {
	sb := strings.builder_make(alloc)
	strings.write_string(&sb, "package atlas_bindings\n\n")

	// Introduce the Rect type
	strings.write_string(&sb, "AtlasRect :: struct { x, y, w, h: i32 }\n\n")
	// start enum
	strings.write_string(&sb, "AtlasSprite :: enum {\n")
	{
		for cell in metadata {
			strings.write_string(&sb, fmt.aprintf("\t%s,\n", cell.name))
		}
	}
	// end enum
	strings.write_string(&sb, "}\n\n")

	// start offsets array
	// todo(stefan): the name of the array can be based on the output name?
	strings.write_string(&sb, "ATLAS_SPRITES := []AtlasRect {\n")
	{
		entry: string
		for cell in metadata {
			entry = fmt.aprintf(
				"\t.%v = {{ x = %v, y = %v, w = %v, h = %v }},\n",
				cell.name,
				cell.location.x,
				cell.location.y,
				cell.size.x,
				cell.size.y,
			)
			strings.write_string(&sb, entry)
		}
	}
	// end offsets array
	strings.write_string(&sb, "}\n\n")

	fmt.println("\n", strings.to_string(sb))

	return sb
}

metadata_source_code_generate :: proc(
	metadata: []SpriteAtlasMetadata,
	code_generation_metadata: Maybe(SourceCodeGeneratorMetadata),
	alloc := context.allocator,
) -> strings.Builder {
	codegen, ok := code_generation_metadata.(SourceCodeGeneratorMetadata)

	if !ok {
		return generate_odin_enums_and_atlas_offsets_file_sb(metadata, alloc)
	}

	sb := strings.builder_make(alloc)
	// strings.write_string(&sb, "package atlas_bindings\n\n")
	strings.write_string(&sb, codegen.file_defines.top)

	// Introduce the Rect type
	// strings.write_string(&sb, "AtlasRect :: struct { x, y, w, h: i32 }\n\n")
	strings.write_string(
		&sb,
		fmt.aprintf(codegen.custom_data_type.type_declaration, codegen.custom_data_type.name),
	)
	// start enum
	// strings.write_string(&sb, "AtlasSprite :: enum {\n")
	strings.write_string(&sb, fmt.aprintf(codegen.enum_data.begin_line, codegen.enum_data.name))
	{
		for cell in metadata {
			// strings.write_string(&sb, fmt.aprintf("\t%s,\n", cell.name))
			strings.write_string(&sb, fmt.aprintf(codegen.enum_data.entry_line, cell.name))
		}
	}
	// end enum
	// strings.write_string(&sb, "}\n\n")
	strings.write_string(&sb, codegen.enum_data.end_line)

	// start offsets array
	// strings.write_string(&sb, "ATLAS_SPRITES := []AtlasRect {\n")
	strings.write_string(
		&sb,
		fmt.aprintf(
			codegen.array_data.begin_line,
			codegen.array_data.name,
			codegen.array_data.type,
		),
	)
	{
		entry: string
		for cell in metadata {
			entry = fmt.aprintf(
				codegen.array_data.entry_line, // "\t.%v = {{ x = %v, y = %v, w = %v, h = %v }},\n",
				cell.name,
				cell.location.x,
				cell.location.y,
				cell.size.x,
				cell.size.y,
			)
			strings.write_string(&sb, entry)
		}
	}
	// end offsets array
	// strings.write_string(&sb, "}\n\n")
	strings.write_string(&sb, codegen.array_data.end_line)

	strings.write_string(&sb, codegen.file_defines.bottom)

	fmt.println("\n", strings.to_string(sb))

	return sb

}
