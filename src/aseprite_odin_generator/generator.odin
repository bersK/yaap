package generator

import ase "../aseprite"
import "core:fmt"
import "core:mem"
import "core:os"
import fp "core:path/filepath"
import "core:slice"
import "core:strings"
import "core:testing"
import rl "vendor:raylib"

ATLAS_SIZE :: 512
EXPORT_PATH :: "E:/dev/odin-atlas-packer/src/aseprite_odin_generator/atlas.png"

main :: proc() {
	fmt.println("Hello!")
	ase_file, ase_ok := os.read_entire_file(
		"E:/dev/odin-atlas-packer/src/aseprite_odin_generator/big.aseprite",
	)
	if !ase_ok {
		fmt.panicf("Couldn't load file!")
	}

	doc: ase.Document
	read, um_err := ase.unmarshal_from_slice(ase_file, &doc)
	if um_err != nil {
		fmt.panicf("Couldn't unmarshall file!")
	} else {
		fmt.printfln("Read {0} bytes from file", read)
	}

	fmt.println("Header:\n\t", doc.header)
	// fmt.println("Frames:\n\t", doc.frames)

	images: [dynamic]rl.Image
	atlas: rl.Image = rl.GenImageColor(ATLAS_SIZE, ATLAS_SIZE, rl.BLANK)

	for frame in doc.frames {
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
				&images,
				rl.Image {
					data = rawptr(&cel_img.pixel[0]),
					width = auto_cast cel_img.width,
					height = auto_cast cel_img.height,
					format = .UNCOMPRESSED_R8G8B8A8,
				},
			)
		}
	}
	curr_x, curr_y: i32
	for img, img_i in images {
		fmt.printfln("Image_{0}: {1}", img_i, img)
		rl.ImageDraw(
			&atlas,
			img,
			{0, 0, auto_cast img.width, auto_cast img.height},
			{auto_cast curr_x, auto_cast curr_y, auto_cast img.width, auto_cast img.height},
			rl.WHITE,
		)
		curr_x += img.width
		curr_y += img.height
	}

	// todo: pack the rectangles

	// todo: blit them to the atlas

	// todo: generate metadata (json, odin enums)

	rl.ExportImage(atlas, EXPORT_PATH)
}
