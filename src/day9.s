	section .text
Prob9a:
	endbr64
	call InitializeMovementData
	lea rsi, [r11 + 8]
	mov ecx, 4
	lea r10, [rel RopeTailPositions]
	mov rax, [r11]
.entryloop:
	sar rax, 1
	rcl ecx, 1
	test rax, rax
	jns .positive
	neg rax ; sets carry
.positive:
	rcl ecx, 1
.step:
	movzx edi, word[r10 + rcx * 2]
	and ecx, 3
	or cl, dil
	shr edi, 8
	add rdx, [rbx + 8 * rdi]
	mov byte[rdx], 1
	dec rax
	jnz .step
	shr ecx, 2
	lodsq
	test rax, rax
	jnz .entryloop
TallyPrintTailPositions:
	mov rdi, r11
	xor esi, esi
	call MapMemory
	mov rsi, rbp
	xor edx, edx
.loop:
	lodsb
	movzx eax, al
	add rdx, rax
	dec r13
	jnz .loop
	mov rax, rdx
	call PrintNumber
	mov rdi, rbp
	xor esi, esi
	jmp MapMemory

Prob9b:
	endbr64
	call InitializeMovementData
	vpxor xmm0, xmm0, xmm0
	vpcmpeqb xmm1, xmm1, xmm1
	vpsubb xmm1, xmm0, xmm1
	vmovdqa xmm6, xmm1
	vmovdqa xmm7, xmm1
	vpaddb xmm2, xmm1, xmm1
	vmovdqa xmm4, xmm1
	vmovdqa xmm5, xmm1
	vpaddb xmm3, xmm2, xmm1
	mov rsi, r11
.entryloop:
	mov r10, [rsi]
	xor eax, eax
	mov ecx, 2
	sar r10, 1
	cmovs ecx, eax
	cmovns eax, ecx
	mov edi, 1
	cmovc eax, edi
	cmovnc ecx, edi
	mov rdi, r10
	neg rdi
	cmovns r10, rdi
	mov edi, 9
	cmovz r10, rdi
	cmovz eax, ecx
	neg ecx
	add ecx, 2
.step:
	vpslldq xmm4, xmm4, 1
	vpslldq xmm6, xmm6, 1
	vpinsrb xmm4, xmm4, eax, 0
	vpinsrb xmm6, xmm6, ecx, 0
	vpaddb xmm8, xmm2, xmm4
	vpaddb xmm9, xmm2, xmm6
	vpsubb xmm8, xmm8, xmm5
	vpsubb xmm9, xmm9, xmm7
	vpcmpgtb xmm10, xmm8, xmm2
	vpcmpgtb xmm11, xmm9, xmm2
	vpcmpeqb xmm14, xmm8, xmm2
	vpcmpeqb xmm15, xmm9, xmm2
	vpaddb xmm10, xmm10, xmm10
	vpaddb xmm11, xmm11, xmm11
	vpsubb xmm10, xmm0, xmm10
	vpsubb xmm11, xmm0, xmm11
	vpsubb xmm10, xmm10, xmm14
	vpsubb xmm11, xmm11, xmm15
	vpsubb xmm14, xmm0, xmm8
	vpsubb xmm15, xmm0, xmm9
	vpsrlq xmm12, xmm8, 2
	vpsrlq xmm13, xmm9, 2
	vpsrlq xmm14, xmm14, 2
	vpsrlq xmm15, xmm15, 2
	vpsubb xmm12, xmm12, xmm14
	vpsubb xmm13, xmm13, xmm15
	vpand xmm12, xmm12, xmm3
	vpand xmm13, xmm13, xmm3
	vpcmpeqb xmm14, xmm12, xmm1
	vpcmpeqb xmm15, xmm13, xmm1
	vpblendvb xmm6, xmm11, xmm13, xmm14
	vpblendvb xmm4, xmm10, xmm12, xmm15
	vpsubb xmm10, xmm2, xmm10
	vpsubb xmm11, xmm2, xmm11
	vpsubb xmm12, xmm2, xmm12
	vpsubb xmm13, xmm2, xmm13
	vpcmpeqb xmm14, xmm12, xmm1
	vpcmpeqb xmm15, xmm13, xmm1
	vpblendvb xmm7, xmm13, xmm11, xmm14
	vpblendvb xmm5, xmm12, xmm10, xmm15
	vpextrb r8d, xmm6, 9 - 1
	vpextrb edi, xmm4, 9 - 1
	lea r8, [r8 * 3]
	add rdi, r8
	add rdx, [rbx + rdi * 8]
	mov byte[rdx], 1
	dec r10
	jnz .step
	lodsq
	test rax, rax
	jnz .entryloop
	jmp TallyPrintTailPositions

InitializeMovementData:
	; out: r11 = movement list (zero terminated), r13 = cell count, rbp = tracking buffer (zero-initialized),
	;      rbx = movement offset array (at end of tracking buffer), rdx = initial head position (in tracking buffer)

	xor r13, r13
	xor r14, r14
	vpxor xmm12, xmm12, xmm12
	vpxor xmm13, xmm13, xmm13
	vpxor xmm14, xmm14, xmm14
.loop:
	call ReadInputLine
	jc .done
	test rdi, rdi
	jz .loop
	movzx eax, byte[rsi]
	vmovd xmm0, eax
	vpcmpistri xmm0, [rel RopeMovementCharacters], 0
	jnc InvalidInputError
	mov r12d, ecx
	inc rsi
	call SkipSpaces
	call ParseNumber
	test rdi, rdi
	jz .loop
	mov r15, rdi
	mov rdi, r13
	add r14, 8
	mov rsi, r14
	call MapMemory
	mov r13, rdi
	mov rax, r15
	neg rax
	shr r12, 1
	cmovnc rax, r15
	lea rsi, [r12 + rax * 2]
	mov [rdi + r14 - 8], rsi
	neg r12
	vmovq xmm0, r12
	vpshufd xmm0, xmm0, 0x44
	vmovq xmm1, rax
	vpshufd xmm2, xmm1, 0x4e
	vpblendvb xmm0, xmm1, xmm2, xmm0
	vpaddq xmm14, xmm14, xmm0
	vpcmpgtq xmm1, xmm14, xmm12
	vpcmpgtq xmm2, xmm14, xmm13
	vpblendvb xmm12, xmm14, xmm12, xmm1
	vpblendvb xmm13, xmm13, xmm14, xmm2
	jmp .loop

.done:
	mov rdi, r13
	lea rsi, [r14 + 8]
	call MapMemory
	vpxor xmm0, xmm0, xmm0
	vpsubq xmm14, xmm13, xmm12
	vpsubq xmm15, xmm0, xmm12
	vmovq r14, xmm15
	vpextrq r15, xmm15, 1
	vmovq rax, xmm14
	inc rax
	mov r12, rax
	vpextrq rdx, xmm14, 1
	inc rdx
	mul rdx
	jc .overflow
	mov r13, rax
	cmp rax, 1
	jz InvalidInputError
	shr rax, 60
	jnz .overflow

	push rdi
	lea rsi, [r13 + 72]
	xor edi, edi
	call MapMemory
	lea rbx, [rdi + rsi - 72]
	mov rbp, rdi
	mov rdi, rbx
	lea rax, [r12 - 1]
	stosq
	inc rax
	stosq
	inc rax
	stosq
	mov rax, -1
	stosq
	xor eax, eax
	stosq
	inc eax
	stosq
	mov rax, r12
	not rax
	stosq
	inc rax
	stosq
	inc rax
	mov [rdi], rax
	pop r11
	mov rax, r15
	lea rdx, [rbp + r14]
	imul rax, r12
	add rdx, rax
	ret

.overflow:
	lea rsi, [rel ErrorMessages.overflow]
	jmp ErrorExit

	section .rodata align=16
RopeMovementCharacters:
	dq "RLUD" ; padding to 8 bytes for alignment
RopeTailPositions:
	; new position and movement for each head movement (RLUD)
	db 3 << 2, 8, 1 << 2, 4, 3 << 2, 4, 1 << 2, 8 ; 0 = left and up
	db 0 << 2, 4, 2 << 2, 4, 4 << 2, 4, 1 << 2, 7 ; 1 = up
	db 1 << 2, 4, 5 << 2, 6, 5 << 2, 4, 1 << 2, 6 ; 2 = right and up
	db 3 << 2, 5, 4 << 2, 4, 6 << 2, 4, 0 << 2, 4 ; 3 = left
	db 3 << 2, 4, 5 << 2, 4, 7 << 2, 4, 1 << 2, 4 ; 4 = same as head
	db 4 << 2, 4, 5 << 2, 3, 8 << 2, 4, 2 << 2, 4 ; 5 = right
	db 3 << 2, 2, 7 << 2, 4, 7 << 2, 2, 3 << 2, 4 ; 6 = left and down
	db 6 << 2, 4, 8 << 2, 4, 7 << 2, 1, 4 << 2, 4 ; 7 = down
	db 7 << 2, 4, 5 << 2, 0, 7 << 2, 0, 5 << 2, 4 ; 8 = right and down
