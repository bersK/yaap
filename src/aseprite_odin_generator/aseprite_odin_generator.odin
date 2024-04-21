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

import gen ".."

ATLAS_SIZE :: 512
IMPORT_PATH :: "./src/aseprite_odin_generator/big.aseprite"
EXPORT_PATH :: "./src/aseprite_odin_generator/atlas.png"

main :: proc() {
	fmt.println("Hello!")
	ase_file, ase_ok := os.read_entire_file(IMPORT_PATH)
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

	atlas: rl.Image = rl.GenImageColor(ATLAS_SIZE, ATLAS_SIZE, rl.BLANK)

	atlas_entry := gen.atlas_entry_from_compressed_cells(doc)
        // Packs the cells & blits them to the atlas
        gen.pack_atlas_entries({atlas_entry}, &atlas)

	rl.ExportImage(atlas, EXPORT_PATH)
}
