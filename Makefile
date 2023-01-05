NASM ?= nasm
LD ?= ld

SRCFILES := $(wildcard src/*.s)

all: aoc22
debug: aoc22dbg

aoc22: aoc22.o linker.sh
	./linker.sh $< $@ 0x400000

aoc22dbg: aoc22.o
	$(LD) $< -o $@

aoc22.o: aoc22.s $(SRCFILES)
	$(NASM) -g -f elf64 -o $@ $<

clean:
	rm -f aoc22.o aoc22 aoc22dbg
