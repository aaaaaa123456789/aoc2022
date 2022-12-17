	absolute wModeData

wTreeGrid: resq 1
wTreeVisibilityGrid: resq 1 ; for each entry: bit 0: top, bit 1: bottom, bit 2: left, bit 3: right
wTreeGridWidth: resd 1
wTreeGridHeight: resd 1
wTreeGridSize: resq 1 ; width * height

wTreeCoordinates: resb 0x30 ; 3 XMM registers

	assert $ <= wModeData.end

	section .text
Prob8a:
	endbr64
	call ReadTreeGrid

	mov rsi, [rel wTreeGridSize]
	xor edi, edi
	call MapMemory
	mov [rel wTreeVisibilityGrid], rdi
	mov r15, rdi
	mov r10, [rel wTreeGridSize]
	lea rcx, [r10 + 7]
	shr rcx, 3
	xor eax, eax
	rep stosq

	mov r12d, [rel wTreeGridWidth]
	mov edx, [rel wTreeGridHeight]
	mov r13d, edx
	mov rsi, [rel wTreeGrid]
	mov r14, rsi
	mov rdi, r15
.leftloop:
	mov ecx, r12d
	xor ebx, ebx
.leftinner:
	lodsb
	cmp bl, al
	jnc .leftskip
	mov byte[rdi], 4
	mov bl, al
.leftskip:
	inc rdi
	dec ecx
	jnz .leftinner
	dec edx
	jnz .leftloop

	std
	mov edx, r13d
	lea rdi, [r15 + r10 - 1]
	mov r9, rdi
	lea rsi, [r14 + r10 - 1]
	mov r8, rsi
.rightloop:
	mov ecx, r12d
	xor ebx, ebx
.rightinner:
	lodsb
	cmp bl, al
	jnc .rightskip
	or byte[rdi], 8
	mov bl, al
.rightskip:
	dec rdi
	dec ecx
	jnz .rightinner
	dec edx
	jnz .rightloop
	cld

	mov edx, r12d
.bottomloop:
	mov rdi, r9
	mov rsi, r8
	dec r9
	dec r8
	mov ecx, r13d
	xor eax, eax
.bottominner:
	cmp al, [rsi]
	jnc .bottomskip
	or byte[rdi], 2
	mov al, [rsi]
.bottomskip:
	sub rsi, r12
	sub rdi, r12
	dec ecx
	jnz .bottominner
	dec edx
	jnz .bottomloop

	mov edx, r12d
	mov rbp, r15
.toploop:
	mov rdi, rbp
	mov rsi, r14
	mov ecx, r13d
	inc rbp
	inc r14
	xor eax, eax
.topinner:
	cmp al, [rsi]
	jnc .topskip
	inc byte[rdi]
	mov al, [rsi]
.topskip:
	add rsi, r12
	add rdi, r12
	dec ecx
	jnz .topinner
	dec edx
	jnz .toploop

	mov rsi, r15
	xor edx, edx
.countloop:
	lodsb
	test al, al
	setnz al
	movzx eax, al
	add rax, rdx
	mov rdx, rax
	dec r10
	jnz .countloop
PrintResultDestroyTree:
	call PrintNumber
	mov rdi, [rel wTreeVisibilityGrid]
	xor esi, esi
	call MapMemory
	mov rdi, [rel wTreeGrid]
	jmp MapMemory

Prob8b:
	endbr64
	call ReadTreeGrid
	mov rsi, [rel wTreeGrid]
	mov rdx, [rel wTreeGridSize]
	lea rbx, [rdx + 3]
	call ValidateDigits
	jc InvalidInputError
	and rbx, -4
	push rbx
	lea rsi, [rbx * 8]
	xor edi, edi
	call MapMemory
	mov [rel wTreeVisibilityGrid], rdi
	pop rbx
	lea r15, [rdi + rbx * 4]
	mov dword[r15 - 12], 0
	mov qword[r15 - 8], 0
	vpxor xmm0, xmm0, xmm0
	vmovdqa xmm1, [rel .digits]
	vmovdqa xmm2, [rel .digits + 16]
	vmovdqa xmm3, [rel .digits + 32]
	vpcmpeqd xmm4, xmm0, xmm0
	vpsubd xmm4, xmm0, xmm4
	lea rbp, [rel wTreeCoordinates]

	mov r13, rdi
	mov rsi, [rel wTreeGrid]
	mov r14, rsi
	mov edx, [rel wTreeGridHeight]
	mov r11d, edx
	mov r12d, [rel wTreeGridWidth]
.leftloop:
	vmovdqa [rbp], xmm0
	vmovdqa [rbp + 16], xmm0
	vmovdqa [rbp + 32], xmm0
	vmovdqa xmm5, xmm0
	mov ecx, r12d
.leftinner:
	call .updatecoords
	inc rsi
	add rdi, 4
	dec ecx
	jnz .leftinner
	dec edx
	jnz .leftloop

	mov r10, [rel wTreeGridSize]
	lea rsi, [r14 + r10 - 1]
	lea rdi, [r15 + 4 * r10 - 4]
	mov edx, r11d
.rightloop:
	vmovdqa [rbp], xmm0
	vmovdqa [rbp + 16], xmm0
	vmovdqa [rbp + 32], xmm0
	vmovdqa xmm5, xmm0
	mov ecx, r12d
.rightinner:
	call .updatecoords
	dec rsi
	sub rdi, 4
	dec ecx
	jnz .rightinner
	dec edx
	jnz .rightloop
	call .multiply

	lea r8, [r14 + r10 - 1]
	lea r9, [r15 + 4 * r10 - 4]
	mov edx, r12d
.bottomloop:
	vmovdqa [rbp], xmm0
	vmovdqa [rbp + 16], xmm0
	vmovdqa [rbp + 32], xmm0
	vmovdqa xmm5, xmm0
	mov ecx, r11d
	mov rsi, r8
	mov rdi, r9
	dec r8
	sub r9, 4
.bottominner:
	call .updatecoords
	sub rsi, r12
	lea rax, [4 * r12]
	sub rdi, rax
	dec ecx
	jnz .bottominner
	dec edx
	jnz .bottomloop
	call .multiply

	mov r9, r15
	lea r8, [4 * r12]
	mov edx, r12d
.toploop:
	vmovdqa [rbp], xmm0
	vmovdqa [rbp + 16], xmm0
	vmovdqa [rbp + 32], xmm0
	vmovdqa xmm5, xmm0
	mov ecx, r11d
	mov rsi, r14
	mov rdi, r9
	inc r14
	add r9, 4
.topinner:
	call .updatecoords
	add rsi, r12
	add rdi, r8
	dec ecx
	jnz .topinner
	dec edx
	jnz .toploop
	call .multiply

.maxloop:
	vpmaxud xmm0, xmm0, [r13]
	add r13, 16
	sub r10, 4
	ja .maxloop
	vpshufd xmm1, xmm0, 0x4e
	vpmaxud xmm0, xmm0, xmm1
	vpshufd xmm1, xmm0, 0x39
	vpmaxud xmm0, xmm0, xmm1
	vmovd eax, xmm0
	jmp PrintResultDestroyTree

.updatecoords:
	movzx eax, byte[rsi]
	vmovd xmm6, eax
	vpshufd xmm6, xmm6, 0
	vmovd ebx, xmm5
	sub ebx, [rbp + rax * 4 - "0" * 4]
	mov [rdi], ebx
	vpcmpgtd xmm7, xmm1, xmm6
	vpblendvb xmm7, xmm5, [rbp], xmm7
	vmovdqa [rbp], xmm7
	vpcmpgtd xmm7, xmm2, xmm6
	vpblendvb xmm7, xmm5, [rbp + 16], xmm7
	vmovdqa [rbp + 16], xmm7
	vpcmpgtd xmm7, xmm3, xmm6
	vpblendvb xmm7, xmm5, [rbp + 32], xmm7
	vmovdqa [rbp + 32], xmm7
	vpaddd xmm5, xmm5, xmm4
	ret

.multiply:
	mov rdi, r13
	mov rsi, r15
	lea rcx, [r10 + 3]
	shr rcx, 2
.multiplyloop:
	vmovdqa xmm5, [rdi]
	vpmulld xmm5, xmm5, [rsi]
	add rsi, 16
	vmovdqa [rdi], xmm5
	add rdi, 16
	dec rcx
	jnz .multiplyloop
	ret

	pushsection .rodata align=16
.digits: dd "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", -0x80000000, -0x80000000
	popsection

ReadTreeGrid:
	call ReadInputLine
	jc InvalidInputError
	test rdi, rdi
	jz ReadTreeGrid
	mov [rel wTreeGridWidth], edi
	xor eax, eax
	mov [rel wTreeGrid], rax
	mov [rel wTreeGridHeight], eax
	mov [rel wTreeGridSize], rax
.loop:
	push rsi
	mov rdi, [rel wTreeGrid]
	mov esi, [rel wTreeGridWidth]
	add rsi, [rel wTreeGridSize]
	call MapMemory
	mov [rel wTreeGrid], rdi
	add rdi, [rel wTreeGridSize]
	pop rsi
	mov ecx, [rel wTreeGridWidth]
	add [rel wTreeGridSize], rcx
	rep movsb
	inc dword[rel wTreeGridHeight]
.readagain:
	call ReadInputLine
	jc Return
	test rdi, rdi
	jz .readagain
	cmp edi, [rel wTreeGridWidth]
	jz .loop
	jmp InvalidInputError
