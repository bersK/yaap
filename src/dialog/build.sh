#!/usr/bin/env bash

gcc ./libtinyfiledialogs/tinyfiledialogs.c -c -o libtinyfiledialogs.o

ar rcs libtinyfiledialogs.a libtinyfiledialogs.o

rm libtinyfiledialogs.o