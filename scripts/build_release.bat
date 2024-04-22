@echo off
odin build src/main_release -define:RAYLIB_SHARED=true -out:build/game_release.exe -no-bounds-check -o:speed -strict-style -vet-unused -vet-using-stmt -vet-using-param -vet-style -vet-semicolon -subsystem:windows
