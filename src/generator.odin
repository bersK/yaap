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
	fp.dir(path)
	if fd, ok := os.open(path); ok == 0 {
		if fi_files, fi_ok := os.read_dir(fd, -1); fi_ok == 0 {
			unmarshall_aseprite_files_file_info(fi_files, atlas_entries)
		}
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
	current_document: ase.Document
	for fp in file_paths {
		atlas_entry := atlas_entry_from_compressed_cells(current_document)
		ase.unmarshal_from_filename(fp, &current_document)
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
        Takes in a slice of entries, an output texture, the width & height 
*/
pack_atlas_entries :: proc(
	entries: []AtlasEntry,
	atlas: ^rl.Image,
	offset_x: int = 0,
	offset_y: int = 0,
) {
	all_entries: [dynamic]rl.Image // it's fine to store it like this, rl.Image just stores a pointer to the data
	// todo: set up the stb_rect_pack rectangles
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
		entry_stb_rect.w = auto_cast entry.width
		entry_stb_rect.h = auto_cast entry.height
	}

	ctx: stbrp.Context
	stbrp.init_target(&ctx, atlas.width, atlas.height, &nodes[0], auto_cast num_entries)
	res := stbrp.pack_rects(&ctx, &rects[0], auto_cast num_entries)
	if bool(res) {
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
			auto_cast rect.x,
			auto_cast rect.y,
			auto_cast cell.width,
			auto_cast cell.height,
		}

		rl.ImageDraw(atlas, cell^, src_rect, dst_rect, rl.WHITE)
	}
}