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

	cwd := os.get_current_directory()
	target_dir := strings.concatenate({cwd, "\\src\\aseprite_odin_generator\\"})

	atlas: rl.Image = rl.GenImageColor(ATLAS_SIZE, ATLAS_SIZE, rl.BLANK)
	atlas_entries: [dynamic]gen.AtlasEntry
	gen.unmarshall_aseprite_dir(target_dir, &atlas_entries)


	gen.pack_atlas_entries(atlas_entries[:], &atlas, 10, 10)

	rl.ExportImage(atlas, EXPORT_PATH)
}
