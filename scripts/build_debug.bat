@echo off
odin build src/main_release -define:RAYLIB_SHARED=true -out:build/game_debug.exe -debug
