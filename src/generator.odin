package game

import ase "./aseprite"
import "core:fmt"
import "core:os"
import fp "core:path/filepath"
import rl "vendor:raylib"
import stbrp "vendor:stb/rect_pack"

AtlasEntry :: struct {
	path:  string,
	cells: [dynamic]rl.Image,
}

unmarshall_aseprite_dir :: proc(path: string, atlas_entries: ^[dynamic]AtlasEntry) {
	if dir_fd, err := os.open(path, os.O_RDONLY); err == os.ERROR_NONE {
		fis: []os.File_Info
		if fis, err = os.read_dir(dir_fd, -1); err == os.ERROR_NONE {
			unmarshall_aseprite_files_file_info(fis, atlas_entries)
		}
	} else {
		fmt.println("Couldn't open folder: ", path)
	}
}

unmarshall_aseprite_files_file_info :: proc(
	files: []os.File_Info,
	atlas_entries: ^[dynamic]AtlasEntry,
) {
	paths: [dynamic]string
	for f in files {
		append(&paths, f.fullpath)
	}
	unmarshall_aseprite_files(paths[:], atlas_entries)
}

unmarshall_aseprite_files :: proc(file_paths: []string, atlas_entries: ^[dynamic]AtlasEntry) {
	aseprite_document: ase.Document
	for file in file_paths {
		extension := fp.ext(file)
		if extension != ".aseprite" {continue}

		fmt.println("Unmarshalling file: ", file)
		ase.unmarshal_from_filename(file, &aseprite_document)
		atlas_entry := atlas_entry_from_compressed_cells(aseprite_document)

		append(atlas_entries, atlas_entry)
	}
}

/*
        Goes through all the chunks in an aseprite document & copies the `Com_Image_Cel` cells in a separate image
*/
atlas_entry_from_compressed_cells :: proc(document: ase.Document) -> (atlas_entry: AtlasEntry) {
	for frame in document.frames {
		for chunk in frame.chunks {
			cel_chunk, cok := chunk.(ase.Cel_Chunk)
			if !cok {
				continue
			}

			cel_img, ci_ok := cel_chunk.cel.(ase.Com_Image_Cel)
			if !ci_ok {
				continue
			}
			append(
				&atlas_entry.cells,
				rl.Image {
					data = rawptr(&cel_img.pixel[0]),
					width = auto_cast cel_img.width,
					height = auto_cast cel_img.height,
					format = .UNCOMPRESSED_R8G8B8A8,
				},
			)
		}
	}
	return
}

/*
        Takes in a slice of entries, an output texture and offsets (offset_x/y)
*/
pack_atlas_entries :: proc(entries: []AtlasEntry, atlas: ^rl.Image, offset_x: i32, offset_y: i32) {
        assert(atlas.width != 0, "This shouldn't be 0!")
        assert(atlas.height != 0, "This shouldn't be 0!")

	all_entries: [dynamic]rl.Image // it's fine to store it like this, rl.Image just stores a pointer to the data
	{
		for entry in entries {
			append(&all_entries, ..entry.cells[:])
		}
	}

	num_entries := len(all_entries)
	nodes := make([]stbrp.Node, num_entries)
	rects := make([]stbrp.Rect, num_entries)

	EntryAndCell :: struct {
		entry:         ^AtlasEntry,
		cell_of_entry: ^rl.Image,
	}
	rect_idx_to_entry_and_cell: map[int]EntryAndCell

	// Set the custom IDs
	cellIdx: int
	for &entry, entryIdx in entries {
		for &cell in entry.cells {
			// I can probably infer this information with just the id of the rect but I'm being lazy right now
			map_insert(&rect_idx_to_entry_and_cell, cellIdx, EntryAndCell{&entry, &cell})
			rects[cellIdx].id = auto_cast entryIdx
			cellIdx += 1
		}
	}

	for entry, entryIdx in all_entries {
		entry_stb_rect := &rects[entryIdx]
		entry_stb_rect.w = stbrp.Coord(entry.width + offset_x * 2)
		entry_stb_rect.h = stbrp.Coord(entry.height + offset_y * 2)
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
		// We're grabbing the whole cell (the image itself)
		src_rect := rl.Rectangle {
			x      = 0,
			y      = 0,
			width  = auto_cast cell.width,
			height = auto_cast cell.height,
		}
		// Placing it in the atlas in the calculated offsets (in the packing step)
		dst_rect := rl.Rectangle {
			auto_cast rect.x + auto_cast offset_x,
			auto_cast rect.y + auto_cast offset_y,
			auto_cast cell.width,
			auto_cast cell.height,
		}
		fmt.printfln("Src rect: {0}\nDst rect:{1}", src_rect, dst_rect)

		rl.ImageDraw(atlas, cell^, src_rect, dst_rect, rl.WHITE)
	}
}
