@echo off
odin build src/main_release -define:RAYLIB_SHARED=false -out:build/game_debug.exe -no-bounds-check -subsystem:windows -debug
