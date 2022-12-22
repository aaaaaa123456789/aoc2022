NASM ?= nasm
LD ?= ld

SRCFILES := $(wildcard src/*.s)

all: aoc22

aoc22: aoc22.s $(SRCFILES) linker.ld shrink.sh
	$(NASM) -f elf64 -o aoc22.o $<
	$(LD) -s -x -T linker.ld aoc22.o -o aoc22
	rm -f aoc22.o
	./shrink.sh $@

debug: aoc22.s $(SRCFILES)
	$(NASM) -g -f elf64 -o aoc22.o $<
	$(LD) aoc22.o -o aoc22
	rm -f aoc22.o

clean:
	rm -f aoc22.o aoc22
