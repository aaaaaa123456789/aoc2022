SECTIONS {
	ENTRY(_start)
	. = 0x400000 + 1; /* +1 to start at next page */
	. = ALIGN(CONSTANT(MAXPAGESIZE));
	.text : {*(.text .rodata)}
	. = ALIGN(CONSTANT(MAXPAGESIZE));
	.bss : {*(.bss)}
}
