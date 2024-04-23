
# YAAP
Yet-Another-Atlas-Packer by Stefan Stefanov

## Description

Simple atlas packer using `stb_rect_pack` from the `stb` family of header libraries & `raylib` for rendering/ui.

The goal of the tool is to take in multiple aseprite files and pack them into a single atlas, outputting some metadata in the process in the form of
json and/or source files for direct use in odin (maybe more languages too).

I'm using a library for marhsalling the aseprite files found [here](https://github.com/blob1807/odin-aseprite) on github.

Project template provided by Karl Zylinski found [here](https://github.com/karl-zylinski/odin-raylib-hot-reload-game-template) on github.
