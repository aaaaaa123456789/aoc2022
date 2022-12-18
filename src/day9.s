	section .text
Prob9a:
	endbr64
	call InitializeMovementData
	lea rsi, [r11 + 8]
	mov ecx, 4
	lea r10, [rel .tailpositions]
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

.tailpositions:
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
	mov eax, "RLUD"
	vmovd xmm1, eax
	vpcmpistri xmm0, xmm1, 0
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
	lea rcx, [r13 + 7]
	shr rcx, 3
	mov rbp, rdi
	xor eax, eax
	rep stosq
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
	lea rsi, [rel .message]
	jmp ErrorExit

.message: db `error: grid size would overflow\n`, 0
