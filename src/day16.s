	absolute wModeData

wValveBitmap: resq 1
wValveFlagPositionList: resb 28

	assert $ <= wModeData.end

	section .text
Prob16a:
	endbr64
	call LoadValveLayoutData
	cmp r12, 64
	lea rsi, [rel ErrorMessages.manynonzero]
	ja ErrorExit
	mov qword[rel wValveBitmap], 0
	mov ebx, 30
	call FindOptimalValveSequence
	call PrintNumber
	mov rdi, r15
	xor esi, esi
	jmp MapMemory

Prob16b:
	endbr64
	call LoadValveLayoutData
	cmp r12, 28
	lea rsi, [rel ErrorMessages.manynonzero]
	jnc ErrorExit
	; call mmap() directly so the resulting mapping is aligned (no mapped header)
	assert MAPPING_ALIGNMENT == 8 << 9
	mov ecx, 9
	cmp rcx, r12
	cmovc rcx, r12
	mov esi, 8
	shl esi, cl
	push rsi
	xor edi, edi
	mov edx, PROT_READ | PROT_WRITE
	mov r10d, MAP_PRIVATE | MAP_ANONYMOUS
	mov r8, -1
	xor r9, r9
	mov eax, mmap
	syscall
	lea rsi, [rel ErrorMessages.allocation]
	test rax, rax
	jle ErrorExit
	pop r9

	mov r8, rax
	mov rcx, r12
	mov r10, -8
	shl r10, cl
	sub rax, r10
	sar r10, 3
	mov r11, rax
	mov qword[rax - 8], -1
.count:
	cmp qword[r11 + r10 * 8], 0
	jnz .next
	mov [rel wValveBitmap], r10
	mov ebx, 26
	mov rcx, r14
	call FindOptimalValveSequence
	not rax
	not rdi
	call .store
.next:
	inc r10
	jnz .count

	mov rcx, r12
	sub ecx, 2
	cmovc rcx, r10 ; r10 = 0
	mov eax, 1
	shl eax, cl
	mov rsi, r8
	lea rdi, [rax * 8 - 4]
	lea rdi, [rsi + rdi * 4]
	vpxor xmm0, xmm0, xmm0
.findmax:
	vmovdqa xmm1, [rsi]
	add rsi, 16
	vmovdqa xmm2, [rdi]
	sub rdi, 16
	vpshufd xmm2, xmm2, 0x4e
	vpaddq xmm1, xmm1, xmm2
	vpcmpgtq xmm2, xmm0, xmm1
	vpblendvb xmm0, xmm0, xmm1, xmm2
	dec eax
	jnz .findmax
	vmovq rax, xmm0
	vpextrq r14, xmm1, 1
	cmp rax, r14
	cmovc r14, rax
	not r14
	dec r14

	mov rdi, r8
	mov rsi, r9
	mov eax, munmap
	syscall
	lea rsi, [rel ErrorMessages.allocation]
	test rax, rax
	jnz ErrorExit
	mov rax, r14
	call PrintNumber
	mov rdi, r15
	xor esi, esi
	jmp MapMemory

.store:
	mov rcx, rax
	mov rsi, rdi
	bsf rax, rdi
	jz .write
	lea rdi, [rel wValveFlagPositionList]
	mov rbx, rdi
.bitloop:
	stosb
	btr rsi, rax
	bsf rax, rsi
	jnz .bitloop
	dec rdi
.writenext:
	cmp rdi, rbx
	jc .write
	movzx eax, byte[rdi]
	dec rdi
	bts r10, rax
	push rdi
	push rax
	call .writenext
	pop rax
	pop rdi
	btr r10, rax
	jmp .writenext

.write:
	mov [r11 + r10 * 8], rcx
	ret

FindOptimalValveSequence:
	; in: ebx: time remaining, ecx, r14d: position, [wValveBitmap]: each bit 0/1 = closed/open
	; out: rax = max score, rdi: valves opened; preserves rbp, r8-r15; expects r12, r13, r15 from LoadValveLayoutData
	mov rdi, [rel wValveBitmap]
	lea rsi, [rcx * 2]
	imul esi, r12d
	add rsi, r13
	xor ecx, ecx
	xor eax, eax
.loop:
	sub bx, [rsi + 2 * rcx]
	jbe .next
	bts [rel wValveBitmap], ecx
	jc .next
	push rsi
	push rdi
	push rax
	push rcx
	call FindOptimalValveSequence
	pop rcx
	mov edx, [r15 + rcx * 4]
	imul rdx, rbx
	add rdx, rax
	pop rax
	pop rsi
	cmp rax, rdx
	cmovc rax, rdx
	cmovnc rdi, rsi
	pop rsi
	btr [rel wValveBitmap], ecx
.next:
	add bx, [rsi + 2 * rcx]
	inc ecx
	cmp rcx, r12
	jc .loop
	ret

LoadValveLayoutData:
	; out: r15 = flow array, r13 (after r15) = distance matrix, rcx = initial, r12 = valve count
	; only nonzero valves are returned (plus an additional row in the distance matrix for the initial valve if needed)
	xor edi, edi
	mov esi, 676 * 8 ; one pointer for each possible valve ID
	call AllocateMemory
	mov r15, rdi
	mov ecx, 676
	xor eax, eax
	rep stosq
	push 0
.readloop:
	call ReadInputLine
	jc .inputdone
	test rdi, rdi
	jz .readloop
	cmp rdi, 8
	jc InvalidInputError
	cmp dword[rsi], "Valv"
	jnz InvalidInputError
	cmp word[rsi + 4], "e "
	jnz InvalidInputError
	inc dword[rsp + 4]
	lea rax, [rsi + rdi + 1]
	mov r12d, -1
.count:
	sub rax, 4
	cmp rax, rsi
	jc InvalidInputError
	inc r12d
	cmp byte[rax], " "
	jz .count
	lea r14, [rax + 5]
	lea r13, [rsi + 8]
	lea rsi, [r12 * 2 + 6]
	xor edi, edi
	call AllocateMemory
	mov ax, [r13 - 2]
	call .convertID
	cmp qword[r15 + 8 * rax], 0
	mov [r15 + 8 * rax], rdi
	jnz InvalidInputError
	mov rsi, r14
	mov r14, rdi
	add rdi, 4
.linkloop:
	mov ax, [rsi]
	add rsi, 4
	call .convertID
	stosw
	dec r12
	jnz .linkloop
	mov word[rdi], -1
	mov rsi, r13
	call SkipNonDigits
	jnc InvalidInputError
	call ParseNumber
	jc InvalidInputError
	mov [r14], edi
	test edi, edi
	jz .readloop
	inc dword[rsp]
	jmp .readloop

.inputdone:
	cmp qword[r15], 0
	jz InvalidInputError
	pop r13
	mov r12d, r13d
	shr r13, 32
	lea rsi, [r13 * 8]
	xor edi, edi
	call AllocateMemory
	xor ecx, ecx
	xor ebp, ebp
	mov rbx, r12
.remaploop:
	mov rax, [r15 + 8 * rcx]
	test rax, rax
	jz .remapnext
	cmp dword[rax], 0
	mov edx, ebp
	cmovz edx, ebx
	mov [rdi + 8 * rdx], rax
	mov [r15 + 8 * rcx], dx
	inc edx
	cmp edx, ebx
	cmovc ebp, edx
	cmovnc ebx, edx
.remapnext:
	inc ecx
	cmp ecx, 676
	jc .remaploop
	xor ecx, ecx
.remaplinks:
	mov rbx, [rdi + 8 * rcx]
	add rbx, 4
	movsx eax, word[rbx]
	cmp eax, -1
	jz InvalidInputError
.remaplink:
	mov rax, [r15 + 8 * rax]
	test rax, rax
	jz InvalidInputError
	cmp ax, cx
	jz InvalidInputError
	mov [rbx], ax
	add rbx, 2
	movsx eax, word[rbx]
	cmp eax, -1
	jnz .remaplink
	inc ecx
	cmp rcx, r13
	jc .remaplinks
	movzx r14d, word[r15]
	xchg rdi, r15
	xor esi, esi
	call AllocateMemory

	lea rsi, [r13 * 2 + 15]
	and esi, -16
	push rsi
	lea rdi, [r13 + 1]
	imul esi, edi
	xor edi, edi
	call AllocateMemory
	pop rbx
	mov rdx, rdi
	add rdi, rbx
	mov rbp, rdi
	sub esi, ebx
	shr esi, 3
	mov ecx, esi
	mov rax, -1
	rep stosq
	mov rdi, rbp
	lea rax, [rbx + 2]
	mov rcx, r13
.selflinks:
	mov word[rdi], 1
	add rdi, rax
	dec ecx
	jnz .selflinks
	vpcmpeqw xmm7, xmm7, xmm7
	vpabsw xmm5, xmm7
.distanceouter:
	xor r11, r11
	vmovdqa xmm6, xmm7
.distanceinner:
	mov rdi, rdx
	mov rcx, rbx
	shr rcx, 3
	mov rax, -1
	rep stosq
	mov rsi, [r15 + r11 * 8]
	add rsi, 4
	lodsw
	inc ax
.distancestep:
	movzx eax, ax
	imul eax, ebx
	mov rdi, rdx
.distanceeach:
	vmovdqa xmm0, [rdi + rax]
	vpminuw xmm0, xmm0, [rdi]
	vmovdqa [rdi], xmm0
	add rdi, 16
	cmp rdi, rbp
	jc .distanceeach
	lodsw
	inc ax
	jnz .distancestep
	mov rdi, rdx
	lea rax, [r11 + 1]
	imul eax, ebx
.mergedistances:
	vpaddusw xmm0, xmm5, [rdi]
	vmovdqa xmm1, [rdi + rax]
	vpminuw xmm0, xmm0, xmm1
	vmovdqa [rdi + rax], xmm0
	add rdi, 16
	vpcmpeqw xmm0, xmm0, xmm1
	vpand xmm6, xmm6, xmm0
	cmp rdi, rbp
	jc .mergedistances
	inc r11
	cmp r11, r13
	jc .distanceinner
	vptest xmm6, xmm7
	jnc .distanceouter

	push rbx
	push rbp
	lea rax, [r14 + 1]
	cmp r14, r12
	cmovc rax, r12
	imul eax, r12d
	add eax, eax
	lea rsi, [rax + r12 * 4]
	xor edi, edi
	call MapMemory
	push rdi
	mov rsi, r15
	mov rcx, r12
.values:
	lodsq
	mov eax, [rax]
	stosd
	dec ecx
	jnz .values
	push r14
	xor r14, r14
	xor esi, esi
.releaseloop:
	mov rdi, [r15 + r14 * 8]
	call AllocateMemory
	inc r14
	cmp r14, r13
	jnz .releaseloop
	mov rdi, r15
	call AllocateMemory
	pop r14
	pop r15
	lea rdi, [r15 + r12 * 4]
	mov r13, rdi
	pop rbp
	pop rbx
	lea rdx, [r14 + 1]
	cmp r14, r12
	cmovc rdx, r12
	mov r10, rbp
.copydistances:
	mov rsi, r10
	add r10, rbx
	mov rcx, r12
	rep movsw
	dec edx
	jnz .copydistances
	mov rdi, rbp
	sub rdi, rbx
	xor esi, esi
	call AllocateMemory
	mov rcx, r14
	ret

.convertID:
	sub ax, "AA"
	cmp al, 26
	jnc InvalidInputError
	cmp ah, 26
	jnc InvalidInputError
	add al, al
	add ah, al
	movzx edx, ah
	movzx eax, al
	lea rdx, [rdx + 4 * rax]
	lea rax, [rdx + 8 * rax]
	ret
