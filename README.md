# Advent of Code 2022 — in x64 assembly!

This is my attempt at the [Advent of Code 2022][aoc2022] challenges, in pure x64 assembly, without any libraries (not
even libc).  
Why? For fun, and because the early days are extremely easy and this makes them challenging. How often does someone
get to write a routine to read a line of input, or to parse a number?

This codebase builds using NASM 2.15.03, and probably (hopefully) any more recent 2.x version; bash and xxd are also
needed for the linking process. The codebase is built for x64 Linux; by its nature, all system calls are hardcoded,
and thus it won't work in any other OS.

To run the program for a specific day, use `./aoc22 <mode>`, where `<mode>` is the day number followed by `a` or `b`.
For example, `./aoc22 1a` will run the very first program. (All modes take input from standard input.)
A few test modes are also included (with some minor documentation in the code itself).

To run the program for all days at once, use the `script` mode, which will read from standard input a list of modes
and associated input files. A sample script has been provided as `script.txt`; to use that script, name all input
files after the corresponding days (`1.txt`, `2.txt`, and so on), and run the program using the sample script as input
(`./aoc22 script < script.txt`); if the files are in another directory, you may pass the path (relative or absolute)
to the program as an additional command-line argument (e.g., if the files reside in a subdirectory called `input`,
invoke the program as `./aoc22 script input/ < script.txt`).

[aoc2022]: https://adventofcode.com/2022
