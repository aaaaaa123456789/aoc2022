	section .text
Prob14a:
	endbr64
	xor eax, eax
	call ReadLayoutGrid
	call ProcessLayout
	jc PrintLayoutTotal
	lea rsi, [rel ErrorMessages.fillup]
	jmp ErrorExit

Prob14b:
	endbr64
	mov eax, 2
	call ReadLayoutGrid
	mov rdi, r13
	mov eax, 1
	mov rcx, r14
	rep stosb
	call ProcessLayout
PrintLayoutTotal:
	call PrintNumber
	mov rdi, r13
	xor esi, esi
	jmp MapMemory

ReadLayoutGrid:
	; in: eax: padding rows
	; out: r13: grid, r14: width, r15: starting position
	push rax
	vpxor xmm15, xmm15, xmm15
	xor r12, r12
	xor r13, r13
	mov rax, -1
	vmovq xmm14, rax
	vpshufd xmm13, xmm14, 3
.readloop:
	call ReadInputLine
	jc .parse
	call .nextpair
	jnc .readloop
	vmovdqa xmm12, xmm0
	mov rdi, r13
	add r12, 2
	push rsi
	lea rsi, [r12 * 4]
	call MapMemory
	mov r13, rdi
	pop rsi
	vmovq [rdi + r12 * 4 - 8], xmm12
.entryloop:
	vpshufd xmm0, xmm12, 0x44
	vpcmpgtd xmm1, xmm0, xmm15
	vpxor xmm1, xmm1, xmm14
	vpblendvb xmm15, xmm15, xmm0, xmm1
.nullentry:
	call .nextpair
	jnc .linedone
	vpcmpeqd xmm1, xmm0, xmm12
	vptest xmm14, xmm1
	jc InvalidInputError
	vpsubd xmm2, xmm0, xmm12
	vphaddd xmm2, xmm2, xmm2
	vmovd r14d, xmm2
	test r14d, r14d
	jz .nullentry
	vptest xmm13, xmm1
	rcl r14d, 1
	vmovdqa xmm12, xmm0
	mov rdi, r13
	inc r12
	push rsi
	lea rsi, [r12 * 4]
	call MapMemory
	mov r13, rdi
	pop rsi
	mov [rdi + r12 * 4 - 4], r14d
	jmp .entryloop

.linedone:
	mov rdi, r13
	inc r12
	lea rsi, [r12 * 4]
	call MapMemory
	mov r13, rdi
	mov dword[rdi + r12 * 4 - 4], 0
	jmp .readloop

.parse:
	test r12, r12
	jz InvalidInputError
	mov r15d, 1
	vpextrd eax, xmm15, 1
	sub r15d, eax
	vpextrd eax, xmm15, 3
	lea r14, [rax + r15 + 2]
	pop rax
	vpextrd esi, xmm15, 2
	test esi, esi
	jz InvalidInputError
	add esi, eax
	lea r14, [r14 + 2 * rsi]
	add r15, rsi
	imul rsi, r14
	add r15, rsi
	add rsi, r14
	xor edi, edi
	call MapMemory
	mov r10, r13
	mov r13, rdi
	add r15, rdi
	mov rsi, r10
.parseloop:
	lodsd
	neg rax
	imul rax, r14
	lea rdi, [rax + r15]
	lodsd
	movsx rax, eax
	add rdi, rax
	sub r12, 2
	mov byte[rdi], 1
.parsemove:
	lodsd
	sar eax, 1
	jz .parsenext
	dec r12 ; doesn't affect carry
	jc .vertical
	mov ecx, eax
	neg eax
	js .moveH
	mov ecx, eax
	std
.moveH:
	mov eax, 1
	rep stosb
	cld
	mov [rdi], al
	jmp .parsemove

.vertical:
	mov rdx, r14
	test eax, eax
	jns .moveV
	neg eax
	neg rdx
.moveV:
	sub rdi, rdx
	mov byte[rdi], 1
	dec eax
	jnz .moveV
	jmp .parsemove

.parsenext:
	dec r12
	jnz .parseloop
	cmp byte[r15], 0
	jnz InvalidInputError
	mov rdi, r10
	xor esi, esi
	jmp MapMemory

.nextpair:
	call SkipNonDigits
	jnc .return
	call ParseNumber
	jc InvalidInputError
	sub edi, 500
	push rdi
	call SkipNonDigits
	jnc InvalidInputError
	call ParseNumber
	jc InvalidInputError
	test edi, edi
	js InvalidInputError
	vmovd xmm0, edi
	pop rdi
	vpinsrd xmm0, edi, 1
	stc
.return:
	ret

ProcessLayout:
	; carry = layout doesn't fill; rax = total iterations
	xor eax, eax
.loop:
	mov rdi, r15
	cmp byte[rdi], 0 ; never sets carry
	jnz ReadLayoutGrid.return ; closer than Return
.move:
	sub rdi, r14
	cmp rdi, r13
	jc ReadLayoutGrid.return
	cmp byte[rdi], 0
	jz .move
	dec rdi
	cmp byte[rdi], 0
	jz .move
	add rdi, 2
	cmp byte[rdi], 0
	jz .move
	mov byte[rdi + r14 - 1], 2
	inc rax
	jmp .loop
