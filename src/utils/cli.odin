package utils

import "core:fmt"
import s "core:strings"

CLIFlagType :: enum {
	Unknown,
	InputFiles,
	InputFolder,
	OutputFolder,
	ConfigPath,
	EnableMetadataOutput,
	MetadataJSONOutputPath,
	SourceCodeOutputPathOutputPath,
	Help,
}

CLI_FLAG_STRINGS := [CLIFlagType][]string {
	.Unknown                        = {""},
	.Help                           = {"h", "help"},
	.InputFiles                     = {"f", "input-files"},
	.InputFolder                    = {"d", "input-directory"},
	.OutputFolder                   = {"o", "out"},
	.EnableMetadataOutput           = {"m", "export-metadata"},
	.ConfigPath                     = {"c", "config"},
	.MetadataJSONOutputPath         = {"j", "json-path"},
	.SourceCodeOutputPathOutputPath = {"s", "source-path"},
}

CLI_FLAG_DESCRIPTIONS := [CLIFlagType]string {
	.Unknown                        = "Invalid flag",
	.Help                           = "Prints the help message... hello!",
	.InputFiles                     = "(real) path the source files for the packer (realpaths only), for multiple files you can provide one string of concateneted paths, separated by a ';'",
	.InputFolder                    = "(real) path to a folder full of source files. This is an alternative to the -i[,input-files] flag",
	.OutputFolder                   = "(real) path to the output folder for all the resulting files to be saved to.",
	.EnableMetadataOutput           = "On by default. Whether or not to export metadata (JSON or source files with the offsets for the packer sprites in the atlas)",
	.ConfigPath                     = "(real) path to a config file (json) that contains string definitions for exporting custom source files. More on this in the docs.",
	.MetadataJSONOutputPath         = "(real) path for the resulting JSON that will be generated for the atlas. It overrides the name & location in regards to the -o[,output-folder] flag",
	.SourceCodeOutputPathOutputPath = "(real) path for the resulting source code file that will be generated for the atlas. It overrides the name & location in regards to the -o[,output-folder] flag",
}

CLIFlag :: struct {
	flag:     string,
	value:    string,
	cli_type: CLIFlagType,
}

categorize_arg :: proc(flag: string) -> (flag_type: CLIFlagType) {
	flag_type = .Unknown
	for flag_strings, enum_flag_type in CLI_FLAG_STRINGS {
		for flag_string in flag_strings {
			if flag == flag_string {
				flag_type = enum_flag_type
				return
			}
		}
	}

	return
}

print_help :: proc() {
	for flag in CLIFlagType {
		if flag == .Unknown do continue

		fmt.printfln(
			"Flag: -%v,%v \t -- %v",
			CLI_FLAG_STRINGS[flag][0],
			CLI_FLAG_STRINGS[flag][1],
			CLI_FLAG_DESCRIPTIONS[flag],
		)
	}
}

parse_arguments :: proc(args: []string) -> (cliargs: map[CLIFlagType]CLIFlag) {
	cliargs = make(map[CLIFlagType]CLIFlag)

	for arg in args {
		arg_name_and_value, err := s.split(arg, ":")
		name := arg_name_and_value[0]

		if name[0] == '-' {
			name = name[1:]
			value: string
			flag_type := categorize_arg(name)

			if len(arg_name_and_value) > 1 {
				value = arg_name_and_value[1]
			}

			map_insert(&cliargs, flag_type, CLIFlag{name, value, flag_type})
		}
	}

	return
}
