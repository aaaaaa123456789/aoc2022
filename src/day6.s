	section .text
Prob6a:
	endbr64
	call ReadInputLine
	jc InvalidInputError
	mov eax, 3
.loop:
	inc rax
	cmp rax, rdi
	ja InvalidInputError
	vlddqu xmm0, [rsi]
	inc rsi
	vpshufb xmm1, xmm0, [rel .interleaved]
	vpshufb xmm0, xmm0, [rel .repeated]
	vpcmpeqb xmm0, xmm0, xmm1
	vptest xmm0, xmm0
	jnz .loop
	call PrintNumber
	xor edi, edi
	ret

	pushsection .rodata align=16
.interleaved: db -1,  1,  2,  3,  0, -1,  2,  3,  0,  1, -1,  3,  0,  1,  2, -1
.repeated:    db  0,  0,  0,  0,  1,  1,  1,  1,  2,  2,  2,  2,  3,  3,  3,  3
	popsection

Prob6b:
	endbr64
	call ReadInputLine
	jc InvalidInputError
	mov eax, 13
.loop:
	inc rax
	cmp rax, rdi
	ja InvalidInputError
	vlddqu xmm0, [rsi]
	inc rsi
	vpshufb xmm1, xmm0, [rel .interleaved]
	vpshufb xmm2, xmm0, [rel .repeated]
	vpcmpeqb xmm3, xmm1, xmm2
	%assign curoffset 16
	%rep 11
		vpshufb xmm1, xmm0, [rel .interleaved + curoffset]
		vpshufb xmm2, xmm0, [rel .repeated + curoffset]
		vpcmpeqb xmm1, xmm1, xmm2
		vpor xmm3, xmm3, xmm1
		%assign curoffset curoffset + 16
	%endrep
	vptest xmm3, xmm3
	jnz .loop
	call PrintNumber
	xor edi, edi
	ret

	pushsection .rodata align=16
.interleaved:
	db  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13
	db  0,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13
	db  0,  1,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13
	db  0,  1,  2,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13
	db  0,  1,  2,  3,  5,  6,  7,  8,  9, 10, 11, 12, 13
	db  0,  1,  2,  3,  4,  6,  7,  8,  9, 10, 11, 12, 13
	db  0,  1,  2,  3,  4,  5,  7,  8,  9, 10, 11, 12, 13
	db  0,  1,  2,  3,  4,  5,  6,  8,  9, 10, 11, 12, 13
	db  0,  1,  2,  3,  4,  5,  6,  7,  9, 10, 11, 12, 13
	db  0,  1,  2,  3,  4,  5,  6,  7,  8, 10, 11, 12, 13
	db  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 11, 12, 13
	db  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 12, 13
	db  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 13
	db  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12
	times 10 db 13
.repeated:
	times 13 db  0
	times 13 db  1
	times 13 db  2
	times 13 db  3
	times 13 db  4
	times 13 db  5
	times 13 db  6
	times 13 db  7
	times 13 db  8
	times 13 db  9
	times 13 db 10
	times 13 db 11
	times 13 db 12
	times 13 db 13
	times 10 db -1
	popsection
