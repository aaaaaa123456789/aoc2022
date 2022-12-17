	section .bss align=16
	assert !(READ_BUFFER_SIZE % 16), "unaligned read buffer size"
wInputBuffer: resb READ_BUFFER_SIZE
wTextBuffer: resb 0x800
wModeData: withend resq 0x200

wOutputFD: resd 1 ; initialize to 1
wInputFD: resd 1
wInputPosition: resw 1 ; initialize to READ_BUFFER_SIZE
wInputEOF: resw 1 ; initialize to READ_BUFFER_SIZE

wAllocationRemainingSpace: resd 1

wCurrentAllocationMapping: resq 1
wLastAllocation: resq 1
