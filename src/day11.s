struc monkey
	.items:   resq 1
	.count:   resq 1
	.passes:  resq 1
	.update:  resd 1 ; low bit: operation (0 = multiply, 1 = add); 0: square
	.divtest: resd 1
	.iftrue:  resd 1
	.iffalse: resd 1
	.size:
endstruc

	section .text
Prob11a:
	endbr64
	call ReadMonkeyList
	mov r14, 20
	lea r15, [rel DivideByThreeCallback]
HandleMonkeyRounds:
	; in: r13 = monkey list, r12 = monkey count, r14 = round count, r15 = post-update handler
	mov rbp, r13
	mov r10, r12
.turn:
	mov rcx, [rbp + monkey.count]
	test rcx, rcx
	jz .turndone
	add [rbp + monkey.passes], rcx
	mov qword[rbp + monkey.count], 0
	mov rsi, [rbp + monkey.items]
	mov r8d, [rbp + monkey.update]
	mov edi, [rbp + monkey.divtest]
	mov r9d, [rbp + monkey.iftrue]
	mov r11d, [rbp + monkey.iffalse]
.item:
	lodsq
	mov edx, r8d
	shr edx, 1
	lea rbx, [rax + rdx]
	cmovc rax, rbx
	mov ebx, 0
	cmovc edx, ebx
	jc .updated
	cmovz rdx, rax
	mul rdx
.updated:
	call r15
	mov rbx, rax
	xor edx, edx
	div rdi
	test rdx, rdx
	mov edx, r9d
	cmovnz edx, r11d
	assert monkey.size == 40
	lea rdx, [rdx * 5]
	lea rdx, [r13 + rdx * 8]
	mov rax, [rdx + monkey.items]
	inc qword[rdx + monkey.count]
	mov rdx, [rdx + monkey.count]
	mov [rax + rdx * 8 - 8], rbx
	dec rcx
	jnz .item
.turndone:
	add rbp, monkey.size
	dec r10
	jnz .turn
	dec r14
	jnz HandleMonkeyRounds

	vpxor xmm0, xmm0, xmm0
	lea rbp, [r13 + monkey.passes]
.tallyloop:
	vpshufd xmm1, [rbp], 0x44
	vpcmpgtq xmm2, xmm1, xmm0
	vpalignr xmm3, xmm1, xmm0, 8
	vpshufd xmm4, xmm2, 0xee
	vpblendvb xmm1, xmm1, xmm3, xmm4
	vpblendvb xmm0, xmm0, xmm1, xmm2
	add rbp, monkey.size
	dec r12
	jnz .tallyloop
	vmovq rax, xmm0
	vpextrq rdx, xmm0, 1
	imul rax, rdx
	call PrintNumber
	mov rdi, r13
	xor esi, esi
	jmp MapMemory

Prob11b:
	endbr64
	call ReadMonkeyList
	mov eax, 1
	lea rbp, [r13 + monkey.divtest]
	mov rcx, r12
.multiplyloop:
	mov edx, [rbp]
	mul rdx
	test rdx, rdx
	jnz .overflow
	add rbp, monkey.size
	dec rcx
	jnz .multiplyloop
	mov [rel wModeData], rax
	mov r14, 10000
	lea r15, [rel .callback]
	jmp HandleMonkeyRounds

.callback:
	endbr64
	xor edx, edx
	div qword[rel wModeData]
	mov rax, rdx
	ret

.overflow:
	lea rsi, [rel .message]
	jmp ErrorExit

.message: db `error: divisors too large\n`, 0

DivideByThreeCallback:
	endbr64
	mov rdx, 0xaaaaaaaaaaaaaaab
	mul rdx
	shr rdx, 1
	mov rax, rdx
	ret

ReadMonkeyList:
	; out: r13 = list, r12 = count
	xor r12, r12
	xor r13, r13
	xor r15, r15
.loop:
	call ReadInputLine
	jc .done
	test rdi, rdi
	jz .loop
	call .parsenumberline
	cmp edi, r12d
	jnz InvalidInputError
	assert monkey.size == 40
	lea rsi, [r12 * 8]
	lea rsi, [rsi * 5 + 40]
	mov rdi, r13
	call MapMemory
	mov r13, rdi
	lea r14, [r12 * 5]
	lea r14, [rdi + r14 * 8]
	xor eax, eax
	mov [r14 + monkey.items], rax
	mov [r14 + monkey.count], rax
	mov [r14 + monkey.passes], rax
	call ReadInputLine
	jc InvalidInputError
	call SkipNonDigits
	jnc .noitems
.itemloop:
	call ParseNumber
	jc InvalidInputError
	push rsi
	push rdi
	mov rsi, [r14 + monkey.count]
	mov rdi, [r14 + monkey.items]
	lea rsi, [rsi * 8 + 8]
	call AllocateMemory
	mov [r14 + monkey.items], rdi
	mov rsi, [r14 + monkey.count]
	inc qword[r14 + monkey.count]
	inc r15
	pop rax
	mov [rdi + rsi * 8], rax
	pop rsi
	call SkipNonDigits
	jc .itemloop
.noitems:
	call ReadInputLine
	jc InvalidInputError
	push rsi
	call SkipNonDigits
	pop rcx
	mov edi, 0
	jnc .square ; assume that a line without digits is of the form "= old * old"
	mov rdi, rsi
	std
	mov eax, " "
	neg rcx
	add rcx, rdi
	dec rdi
	repz scasb
	cld
	push rdi
	call ParseNumber
	pop rax
	jc InvalidInputError
	; assume that a line that doesn't end with "* <number>" indicates an addition
	cmp byte[rax + 1], "*"
	setnz al
	shr al, 1
	rcl edi, 1
	test edi, edi
	jz InvalidInputError ; * 0 is not valid
.square:
	mov [r14 + monkey.update], edi
	call .nextnumberline
	test edi, edi
	jz InvalidInputError
	mov [r14 + monkey.divtest], edi
	call .nextnumberline
	cmp edi, r12d
	jz .invalidmonkey
	mov [r14 + monkey.iftrue], edi
	call .nextnumberline
	cmp edi, r12d
	mov [r14 + monkey.iffalse], edi
	lea r12, [r12 + 1]
	jnz .loop
.invalidmonkey:
	lea rsi, [rel .message]
	jmp ErrorExit

.done:
	test r12, r12
	jz InvalidInputError
	lea rsi, [r15 * 8 + monkey.size]
	imul rsi, r12
	mov rdi, r13
	call MapMemory
	mov r13, rdi
	assert monkey.size == 40
	mov r14, r12
	lea rsi, [r12 * 5]
	lea rdx, [rdi + rsi * 8]
	mov rbp, rdi
.checkloop:
	mov eax, [rbp + monkey.iftrue]
	cmp eax, r12d
	jnc .invalidmonkey
	mov eax, [rbp + monkey.iffalse]
	cmp eax, r12d
	jnc .invalidmonkey
	mov rsi, [rbp + monkey.items]
	mov rdi, rdx
	mov rcx, [rbp + monkey.count]
	rep movsq
	mov rdi, [rbp + monkey.items]
	xor esi, esi
	push rbp
	push rdx
	call AllocateMemory
	pop rdx
	pop rbp
	mov [rbp + monkey.items], rdx
	lea rdx, [rdx + r15 * 8]
	add rbp, monkey.size
	dec r14
	jnz .checkloop
	ret

.nextnumberline:
	call ReadInputLine
	jc InvalidInputError
.parsenumberline:
	call SkipNonDigits
	jnc InvalidInputError
	call ParseNumber
	jc InvalidInputError
	ret

.message: db `error: invalid throw target\n`, 0
