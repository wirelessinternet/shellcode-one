#!/bin/bash
rm ./a.out
nasm -f elf32 shell.asm && ld -m elf_i386 shell.o && ./a.out
