	section .bss align=16
	assert !(READ_BUFFER_SIZE % 16), "unaligned read buffer size"
wInputBuffer: resb READ_BUFFER_SIZE
wTextBuffer: resb 0x800
wModeData: withend resq 0x200

	section .data align=16
wOutputFD: dd 1
wInputFD: dd 0
wInputPosition: dw READ_BUFFER_SIZE
wInputEOF: dw READ_BUFFER_SIZE

wAllocationRemainingSpace: dd 0

wCurrentAllocationMapping: dq 0
wLastAllocation: dq 0
