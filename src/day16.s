	absolute wModeData

wValveBitmap: resq 11 ; 676 / 64, rounded up

	assert $ <= wModeData.end

	section .text
Prob16a:
	endbr64
	call LoadValveLayoutData
	mov ebx, 30
	call FindOptimalValveSequence
	call PrintNumber
	mov rdi, r15
	xor esi, esi
	jmp MapMemory

Prob16b:
	endbr64
	call LoadValveLayoutData
	lea rsi, [r12 * 4]
	lea rdi, [rsi * 5]
	lea rdi, [rdi * 5]
	add esi, edi
	xor edi, edi
	call MapMemory
	mov rbp, rdi
	imul r14d, r12d
	lea rsi, [r13 + r14 * 2]
	mov rbx, rsi
	mov rcx, r12
	rep movsw
	mov rsi, rbx
	mov rcx, r12
	rep movsw
	mov rcx, r12
	mov r14d, 26
	call .findoptimal
	lea r14, [rbp + r12 * 4]
	call PrintNumber
	mov rdi, r14
	xor esi, esi
	call MapMemory
	mov rdi, r15
	jmp MapMemory

.nextoptimal:
	mov rax, rbp
	lea rsi, [rbp + r12 * 2]
	mov dx, [rbp + rcx * 2]
	lea rbp, [rbp + r12 * 4]
	mov rdi, rbp
	lea rbx, [rbp + r12 * 2]
	cmp rcx, r12
	jc .lowhalf
	mov rsi, rax
	xchg rbx, rdi
	sub rcx, r12
.lowhalf:
	imul ecx, r12d
	lea r10, [r13 + rcx * 2]
	mov rcx, r12
.subtract:
	lodsw
	sub ax, dx ; deliberate underflow if ax < dx
	mov [rbx], ax
	add rbx, 2
	dec ecx
	jnz .subtract
	mov rsi, r10
	mov rcx, r12
	rep movsw
	; rcx = 0
	cmp rbx, rdi
	jc .findoptimal
	sub rcx, r12
	lea rsi, [rbp + r12 * 4]
.clearzeros:
	; if a value in the second half is zero, make it underflow
	cmp word[rsi + 2 * rcx], 1
	sbb word[rsi + 2 * rcx], 0
	inc rcx
	jnz .clearzeros
	; rcx = 0
.findoptimal:
	xor eax, eax
.loop:
	sub r14w, [rbp + 2 * rcx]
	jbe .next
	mov ebx, ecx
	sub rbx, r12
	cmovc ebx, ecx
	bts [rel wValveBitmap], ebx
	jc .next
	push rax
	push rcx
	call .nextoptimal
	pop rcx
	mov ebx, ecx
	sub rbx, r12
	cmovc ebx, ecx
	mov edx, [r15 + rbx * 4]
	imul rdx, r14
	add rdx, rax
	pop rax
	cmp rax, rdx
	cmovc rax, rdx
	btr [rel wValveBitmap], ebx
.next:
	add r14w, [rbp + 2 * rcx]
	inc ecx
	lea rbx, [r12 * 2]
	cmp ecx, ebx
	jc .loop
	lea rcx, [r12 * 4]
	sub rbp, rcx
	ret

FindOptimalValveSequence:
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
	btr [rel wValveBitmap], ecx
.next:
	add bx, [rsi + 2 * rcx]
	inc ecx
	cmp rcx, r12
	jc .loop
	ret

LoadValveLayoutData:
	; out: r15 = flow array, r13 (after r15) = distance matrix, rcx = initial position, r12 = valve count
	; first r12 bits in wValveBitmap are also cleared to be used for valve tracking later on
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

	lea rcx, [r12 + 63]
	shr ecx, 6
	lea rdi, [rel wValveBitmap]
	xor eax, eax
	rep stosq
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
