#!/usr/bin/env bash

odin build src/main_release -out:build/game_release.bin -no-bounds-check -o:speed -strict-style -vet-unused -vet-using-stmt -vet-using-param -vet-style -vet-semicolon
