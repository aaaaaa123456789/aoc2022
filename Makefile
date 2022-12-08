NASM ?= nasm
LD ?= ld

SRCFILES := $(wildcard src/*.s)

all: aoc22.s $(SRCFILES)
	$(NASM) -f elf64 -o aoc22.o $<
	$(LD) -s -x aoc22.o -o aoc22
	rm -f aoc22.o

debug: aoc22.s $(SRCFILES)
	$(NASM) -g -f elf64 -o aoc22.o $<
	$(LD) aoc22.o -o aoc22
	rm -f aoc22.o

clean:
	rm -f aoc22.o aoc22
