package generator

import ase "../aseprite"
import "core:encoding/json"
import "core:fmt"
import "core:mem"
import "core:os"
import fp "core:path/filepath"
import "core:slice"
import s "core:strings"
import "core:testing"

import rl "vendor:raylib"
import stbrp "vendor:stb/rect_pack"

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
	target_dir := s.concatenate({cwd, "\\src\\aseprite_odin_generator\\"})

	atlas: rl.Image = rl.GenImageColor(ATLAS_SIZE, ATLAS_SIZE, rl.BLANK)
	atlas_entries: [dynamic]gen.AtlasEntry = make([dynamic]gen.AtlasEntry)
	gen.unmarshall_aseprite_dir(target_dir, &atlas_entries)

	metadata := gen.pack_atlas_entries(atlas_entries[:], &atlas, 10, 10)

	json_bytes, jerr := json.marshal(metadata)
	os.write_entire_file("src/aseprite_odin_generator/metadata.json", json_bytes)
	sb := gen.metadata_source_code_generate(metadata[:], gen.odin_source_generator_metadata)
	odin_output_str := s.to_string(sb)
	os.write_entire_file(
		"src/aseprite_odin_generator/output.odino",
		transmute([]byte)odin_output_str,
	)

	rl.ExportImage(atlas, EXPORT_PATH)

	// TestStruct :: struct {
	// 	something: struct {
	// 		name: string,
	// 		age:  int,
	// 	},
	// }
        // ts: TestStruct
        // ts.something.name = "name"

        // jb, err := json.marshal(ts)
        // sjb := transmute(string)jb
        // fmt.println(sjb)
}
