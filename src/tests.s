	section .text

TestCat:
	; simple test cat program, to make sure input and output work correctly
	endbr64
.loop:
	call ReadInputLine
	jc .done
	call PrintMessage
	; inefficient, but this is just a test
	lea rsi, [rel .newline]
	call PrintMessage
	jmp .loop
.done:
	xor edi, edi
	ret

.newline: db `\n`, 0
