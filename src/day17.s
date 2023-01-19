	section .text
Prob17a:
	endbr64
	call PrepareRockData
	push 2022
.loop:
	call DropRock
	dec dword[rsp]
	jnz .loop
	pop rax ; dummy
	mov rax, r15
	call PrintNumber
	lea rdi, [r12 - 1]
	xor esi, esi
	jmp MapMemory

PrepareRockData:
	; out: r12: initial buffer, rsi: buffer size, r13: input, r14, r15: zero, {xmm15, xmm14}: rock list, rax: input size
	call ReadInputLine
	jc InvalidInputError
	test rdi, rdi
	jz PrepareRockData
	mov r13, rsi
	xor edi, edi
	mov esi, 1
	call MapMemory
	lea r12, [rdi + 1]
	mov rcx, rsi
	shr rcx, 3
	mov rax, 0x8080808080808080
	rep stosq
	mov byte[r12 - 1], -1
	xor r14, r14
	xor r15, r15
	sub rsi, 8
	mov ebx, 0x00001818
	vmovd xmm14, ebx
	vmovdqa xmm15, [rel .rocks]
	ret

	pushsection .rodata align=16
.rocks:
	; excluding the last one (manually loaded)
	dd 0x0000001e, 0x00081c08, 0x0004041c, 0x10101010
	popsection

DropRock:
	; expects: r12: buffer, rsi: effective size (true size - 8), r14: input position, r13: input base, r15: height,
	;          {xmm15, xmm14}: rock list
	; updates those registers, preserves xmm12 and xmm13 and clobbers everything else
	cmp r15, rsi
	jc .go
	push rsi
	lea rdi, [r12 - 1]
	lea rsi, [r15 + 8]
	call MapMemory
	lea r12, [rdi + 1]
	pop rcx
	add rdi, rcx
	neg rcx
	add rcx, rsi
	sub rsi, 8
	shr rcx, 3
	mov rax, 0x8080808080808080
	rep stosq
.go:
	lea rdx, [r15 + 3]
	vmovd ebx, xmm15
	vpalignr xmm15, xmm14, xmm15, 4
	vmovd xmm14, ebx
.loop:
	mov eax, ebx
	rol eax, 2
	cmp byte[r14 + r13], ">"
	cmovz eax, ebx
	inc r14
	movzx ecx, byte[r14 + r13]
	test ecx, ecx
	cmovz r14, rcx
	ror eax, 1
	test eax, [r12 + rdx]
	cmovz ebx, eax
	dec rdx
	test ebx, [r12 + rdx]
	jz .loop
	or [r12 + rdx + 1], ebx
	lea rdi, [r12 + r15]
	mov al, 0x80
	mov rcx, -1
	repnz scasb
	lea r15, [rdi - 1]
	sub r15, r12
	ret
