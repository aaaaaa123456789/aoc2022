	section .bss align=16
	assert !(READ_BUFFER_SIZE % 16), "unaligned read buffer size"
wInputBuffer: resb READ_BUFFER_SIZE
wTextBuffer: resb 0x800

	section .data align=16
wOutputFD: dd 1
wInputFD: dd 0
wInputPosition: dw READ_BUFFER_SIZE
wInputEOF: dw READ_BUFFER_SIZE

	dd 0 ; padding

	section .text

ReadInputLine:
	; input: none
	; output: rsi = pointer to line (null terminated); edi = line length; carry flag = EOF (rsi and rdi invalid)
	; assumes lines are shorter than READ_BUFFER_SIZE and will split longer lines
	movzx ecx, word[rel wInputEOF]
	movzx eax, word[rel wInputPosition]
	sub ecx, eax
	jbe .doread
.readline:
	lea rdi, [rel wInputBuffer]
	add rdi, rax
	mov rsi, rdi
	mov al, `\n`
	repnz scasb
	jnz .doread
.gotline:
	dec rdi
	mov byte[rdi], 0
	sub rdi, rsi
	movzx eax, word[rel wInputPosition]
	lea rax, [rax + rdi + 1]
	mov [rel wInputPosition], ax
	ret

.doread:
	movzx ecx, word[rel wInputEOF]
	cmp ecx, READ_BUFFER_SIZE
	jb .atEOF
	movzx edx, word[rel wInputPosition]
	sub cx, dx
	mov word[rel wInputPosition], 0
	lea rdi, [rel wInputBuffer]
	jz .nocopy
	rep movsb
.nocopy:
	mov rsi, rdi
.readloop:
	push rsi
	push rdx
	mov edi, [rel wInputFD]
	assert read == 0
	xor eax, eax
	syscall
	pop rdx
	pop rsi
	cmp rax, -EINTR
	jz .readloop
	cmp eax, 0
	jz .EOF
	jl .error
	add rsi, rax
	sub edx, eax
	jnz .readloop
	; same as above, but assume the terminator is found somewhere
	lea rdi, [rel wInputBuffer]
	mov rsi, rdi
	mov al, `\n`
	mov ecx, READ_BUFFER_SIZE
	repnz scasb
	jmp .gotline

.EOF:
	mov byte[rsi], `\n` ; in case the last line of the file doesn't end in a newline
	lea rdi, [rel wInputBuffer]
	sub rsi, rdi
	mov [rel wInputEOF], si
	jmp ReadInputLine

.errormessage: db `error: input failed\n`, 0

.error:
	mov edi, [rel wOutputFD]
	push rdi
	mov dword[rel wOutputFD], 2
	lea rsi, [rel .errormessage]
	call PrintMessage
	pop rdi
	mov [rel wOutputFD], edi
	mov word[rel wInputEOF], 0
.atEOF:
	xor esi, esi
ReturnCarryOneOutput:
	xor edi, edi
	stc
	ret

PrintNumber:
	; in: rax: number
	lea rdi, [rel wTextBuffer]
	call NumberToString
	mov word[rdi], `\n`
	lea rsi, [rel wTextBuffer]
PrintMessage:
	; in: rsi: string
	xor eax, eax
	mov rcx, -1
	mov rdi, rsi
	repnz scasb
	sub rdi, rsi
	lea rdx, [rdi - 1]
.writeloop:
	mov edi, [rel wOutputFD]
	push rsi
	push rdx
	mov eax, write
	syscall
	pop rdx
	pop rsi
	cmp rax, -EINTR
	jz .writeloop
	cmp rax, 0
	jle .done
	add rsi, rax
	sub rdx, rax
	jnz .writeloop
.done:
	ret

ParseNumber:
	; in: rsi: string pointer (pointing to an optional sign and max 15 digits)
	; out: rdi: parsed number, rsi: updated string pointer, carry: error
	xor ebx, ebx
	cmp byte[rsi], "+"
	jz .skip
	cmp byte[rsi], "-"
	jnz .go
	inc ebx
.skip:
	inc rsi
.go:
	vlddqu xmm0, [rsi]
	mov eax, "09"
	vmovd xmm1, eax
	mov eax, 2
	mov edx, 16
	vpcmpestri xmm1, xmm0, 0x14
	jo ReturnCarryOneOutput
	jnc ReturnCarryOneOutput
	add rsi, rcx
	xor ecx, 15
	lea rax, [rel SwappedIndexes + 1]
	vpshufb xmm0, xmm0, [rax + rcx]
	lea rax, [rel .mask + 1]
	vlddqu xmm1, [rax + rcx]
	vpblendvb xmm2, xmm0, [rel .zerodigits], xmm1
	vpsubb xmm0, xmm0, xmm2
	vpxor xmm1, xmm1, xmm1
	vpunpcklbw xmm6, xmm0, xmm1
	vpunpckhbw xmm7, xmm0, xmm1
	vpunpcklwd xmm2, xmm6, xmm1
	vpunpckhwd xmm3, xmm6, xmm1
	vpunpcklwd xmm4, xmm7, xmm1
	vpunpckhwd xmm5, xmm7, xmm1
	vpmulld xmm2, xmm2, [rel .digitvalues]
	vpmulld xmm3, xmm3, [rel .digitvalues + 16]
	vpmulld xmm4, xmm4, [rel .digitvalues]
	vpmulld xmm5, xmm5, [rel .digitvalues + 16]
	vpaddd xmm2, xmm2, xmm3
	vpaddd xmm3, xmm4, xmm5
	vphaddd xmm0, xmm2, xmm3
	vphaddd xmm0, xmm0, xmm1
	vpextrd eax, xmm0, 1
	vpextrd edi, xmm0, 0
	imul rax, 100000000
	add rax, rdi
	mov rdi, rax
	neg rax
	test ebx, ebx
	cmovnz rdi, rax
	ret

	pushsection .rodata align=16
.mask:
	times 16 db -1
.zerodigits:
	times 16 db "0" ; also the second half of the mask
.digitvalues:
	dd 1, 10, 100, 1000
	dd 10000, 100000, 10000000, 100000000
	popsection

NumberToString:
	; in: rax: number, rdi: string buffer (will be moved forwards); assumes the number fits in 16 digits
	test rax, rax
	jns .positive
	mov byte[rdi], "-"
	inc rdi
	neg rax
.positive:
	mov ecx, 10
	vmovdqa xmm0, [rel SwappedIndexes]
.loop:
	xor edx, edx
	div ecx
	add edx, "0"
	vpslldq xmm0, xmm0, 1
	vpinsrb xmm0, xmm0, edx, 0
	test rax, rax
	jnz .loop
	vmovdqu [rdi], xmm0
	vpextrb ecx, xmm0, 15
	mov edx, 16
	cmp ecx, edx
	cmovnc ecx, edx
	add rdi, rcx
	ret

	section .rodata align=16
SwappedIndexes:
	db 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0
	times 16 db 0
