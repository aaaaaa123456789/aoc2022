	absolute wModeData

wTreeGrid: resq 1
wTreeVisibilityGrid: resq 1 ; for each entry: bit 0: top, bit 1: bottom, bit 2: left, bit 3: right
wTreeGridWidth: resd 1
wTreeGridHeight: resd 1
wTreeGridSize: resq 1 ; width * height

	assert $ <= wModeData.end

	section .text
Prob8a:
	endbr64
	call ReadTreeGrid
	call ComputeTreeVisibility
	mov rsi, [rel wTreeVisibilityGrid]
	mov rcx, [rel wTreeGridSize]
	xor edx, edx
.loop:
	lodsb
	test al, al
	setnz al
	movzx eax, al
	add rax, rdx
	mov rdx, rax
	dec rcx
	jnz .loop
	call PrintNumber
	mov rdi, [rel wTreeVisibilityGrid]
	xor esi, esi
	call MapMemory
	mov rdi, [rel wTreeGrid]
	jmp MapMemory

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

ComputeTreeVisibility:
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
.toploop:
	mov rdi, r15
	mov rsi, r14
	mov ecx, r13d
	inc r15
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

	ret
